FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    nginx curl lua-cjson \
    tree less vim \
    libnginx-mod-http-lua \
    && rm -rf /var/lib/apt/lists/*

# Enable Lua module (optional)
#RUN ln -s /usr/share/nginx/modules-available/mod-http-lua.conf /etc/nginx/modules-enabled/

# Redisrect logs to stdout/stderr for docker logs
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 90
CMD ["nginx", "-g", "daemon off;"]


