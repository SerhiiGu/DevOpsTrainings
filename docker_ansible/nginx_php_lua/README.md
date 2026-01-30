docker exec -it nginx bash

### in the nginx container
curl -v http://localhost:90/lua_test

curl -X POST -d "user=Ivan&role=admin&token=qwerty123" http://localhost:90/lua_post_test

curl -X POST -d "user=banned2&role=admin&token=qwerty123" http://localhost:90/lua_to_php


docker-compose up -d --build


===========================================

JSON - додати пакет "apt install lua-cjson"

curl -X POST http://localhost:90/lua_json_test \
     -H "Content-Type: application/json" \
     -d '{"user": "Admin_UA", "email": "test@example.com", "status": "active"}'

ngx.req.get_body_data(): Ця функція повертає дані, тільки якщо вони помістилися в пам'ять
(за це відповідає директива client_body_buffer_size).
Якщо запит великий, дані будуть у файлі, тому в коді вище додана перевірка ngx.req.get_body_file().

pcall: Ми використовуємо pcall (protected call) для cjson.decode.
Це важливо, бо якщо прийде "битий" JSON, функція decode викличе фатальну помилку Lua, і Nginx поверне 500.
pcall дозволяє обробити помилку м'яко.


===========================================

Lua розпарсить JSON, візьме звідти ім'я користувача і додасть його у новий заголовок X-Lua-User, який потім прочитає PHP.

curl -X POST http://localhost:90/process_json \
     -H "Content-Type: application/json" \
     -d '{"user": "Dmitry", "action": "login"}'

Валідація: Lua може перевірити JSON-токен або формат даних ще до того, як "важкий" PHP-процес почне працювати. Якщо дані невалідні, Lua може віддати ngx.exit(400) відразу.

Мікросервіси: Ви можете автоматично додавати ID запиту (X-Request-ID) для трейсингу.

Адаптація: Ви можете змінювати шлях до файлу або навіть вибирати інший PHP-бекенд залежно від того, що знаходиться всередині JSON.


=============================================

NEW /process_json
NEW /lua_to_php

Кеш-ключ для POST: Якщо ви не додасте $request_body у fastcgi_cache_key, то запит {"id": 1} та {"id": 2} повернуть однаковий результат (перший, що потрапив у кеш).

Розмір буфера: client_body_buffer_size має бути більшим за ваш типовий JSON. Якщо тіло запиту запишеться у тимчасовий файл на диск, змінна $request_body в Nginx стане порожньою, і кешування зламається.

Заголовки PHP: Якщо ваш PHP-код надсилає Set-Cookie або Cache-Control: no-store, Nginx не буде кешувати запит. Щоб це ігнорувати, додайте в конфіг Nginx:
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;

TEST: TWICE
curl -i -X POST -H "Content-Type: application/json" -d '{"user":"test"}' http://localhost:90/process_json


==============================================

BLOCK /process_json_2

### X-Cache-Status: MISS => X-Cache-Status: HIT
curl -i -X POST -d '{"user":"ivan"}' http://localhost:90/process_json_2

### X-Cache-Status: BYPASS, а заголовок X-Lua-Skip-Used: 1
curl -i -X POST -d '{"user":"ivan", "nocache": true}' http://localhost:90/process_json_2

### X-Cache-Status: BYPASS
curl -i -X POST -d '{"user":"admin"}' http://localhost:90/process_json_2

Різниця між bypass та no_cache:
    fastcgi_cache_bypass: Nginx навіть не заглядатиме в кеш, а відразу піде до PHP.
    fastcgi_no_cache: Nginx отримає відповідь від PHP, але не покладе її в папку кешу для майбутніх запитів.
    Для повної ігнорації кешу (як у прикладі з адміном) потрібно використовувати обидві директиви одночасно.


===============================================

Cache if request have only allowed fields, and only for the list with allowed for caching URI

```location /cache_only_allowed_fields_json + location @disk_cache```

Get a POST query and parse it. Cache only if we have fields from the explicitly stated list.

We have the list of accepted fields for caching: Ex.: "page" and "valid".

Also, we have the **list of allowed URIs** for caching(allowed_uris). Wildcard doesn't accepted!

If we get POST only with these fields - we can cache them. If we have ANY OTHER field - skip a cache. The same logic with an URI. See in the tests below.

```bash
# MISS => HIT
curl -i -X POST -d '{"page":"qwerty"}' http://localhost:90/cache_only_allowed_fields_json
curl -i -X POST -d '{"page":"qwerty", "valid":"1d"}' http://localhost:90/cache_only_allowed_fields_json
# Everytime BYPASS
curl -i -X POST -d '{"page":"qwerty", "cookie": "SMTH..."}' http://localhost:90/cache_only_allowed_fields_json
curl -i -X POST -d '{"valid":"2w", "cookie": "SMTH...", "nocache": true}' http://localhost:90/cache_only_allowed_fields_json
```


=================================================

Purge cache URI with grep. Slow variant, generates high I/O, but it's relaible.  Wildcard by default!

```location /purge_cache```

```curl -i -X POST -d '{"pages": ["/page-for-item1", "/page-for-query/234"]}' http://localhost:90/purge_cache```

And it must delete cache pages like:

```bash
/page-for-item1
/page-for-item1/
/page-for-item1-smth2 (in general: /page-for-item1*)
/page-for-query/234
/page-for-query/234*
```

Puge ALL cache:
```bash
curl -i -X POST -d '{"pages": ["/"]}' http://localhost:90/purge_cache
```


=================================================

Fast way to purge cache URI, but LUA table stores only in RAM, and after restart nginx(not reload) it may not found files even if they will be at the FS

```location /purge_cache_lua_table```

You may send list of URIs from the beginning (from /). Exact or wildcard accepted:

```bash
curl -i -X POST -d '{"pages": ["/cache_only_allowed_fields_json/"]}' http://localhost:90/purge_cache_lua_table
curl -i -X POST -d '{"pages": ["/cache_only_allowed_fields_json/a.php", "cache_only_allowed_fields_json/"]}' http://localhost:90/purge_cache_lua_table
curl -i -X POST -d '{"pages": ["/cache_only_allowed_fields_json/*"]}' http://localhost:90/purge_cache_lua_table #same as previous, but as wildcard
```

Pugre ALL cache from the table:
```bash
curl -i -X POST -d '{"pages": ["*"]}' http://localhost:91/purge_cache_lua_table
```


==================================================

For debug purposes: get total number of rows(URI) and keys(cache files) in the LUA table, and up to 1000 rows itself

```
curl http://localhost:90/debug_cache_total
curl http://localhost:90/debug_cache_list | jq
```


==================================================

## Port 92: Cache by allowing header

Yes(X-Allow-Cache: yes):
```bash
curl -i -X POST -d '{"page":"qwerty", "valid":"1d"}' http://localhost:92/cache1
```

No(other header flag, no header, and default behaviour):
```bash
curl -i -X POST -d '{"page":"qwerty"}' http://localhost:92/testcase2
curl -i -X POST -d '{"test":"no_header"}' http://localhost:92/noheader
curl -i -X POST -d '{"foo":"bar"}' http://localhost:92/something-else
```

Endpoint: ```www/mobile-api_92.php```, config: ```nginx/mobile-api_92.conf```

