docker exec -it nginx_php_lua-nginx-1 bash

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

