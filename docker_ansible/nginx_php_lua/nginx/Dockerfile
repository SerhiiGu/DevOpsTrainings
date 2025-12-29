FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    nginx curl lua-cjson \
    libnginx-mod-http-lua \
    && rm -rf /var/lib/apt/lists/*

# Включаємо модуль Lua (optional)
#RUN ln -s /usr/share/nginx/modules-available/mod-http-lua.conf /etc/nginx/modules-enabled/

# Спрямовуємо логи в stdout/stderr для docker logs
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 90
CMD ["nginx", "-g", "daemon off;"]


