-- Get nginx cache TTL

if ngx.var.upstream_cache_status == "HIT" then
    local key = ngx.var.full_key
    local hash = ngx.md5(key)
    local path = "/var/cache/nginx/" .. string.sub(hash, -2) .. "/" .. string.sub(hash, -4, -3) .. "/" .. hash

    local f = io.open(path, "rb")
    if f then
        f:seek("set", 8)
        local bytes = f:read(8)
        f:close()

        if bytes and #bytes == 8 then
            local b1, b2, b3, b4, b5, b6, b7, b8 = string.byte(bytes, 1, 8)
            local timestamp = b1 + b2*256 + b3*65536 + b4*16777216

            local age = timestamp - ngx.time()
            ngx.header["X-Cache-Expires-In"] = age .. "s"
            ngx.header["X-Cache-Expires-At"] = os.date("!%Y-%m-%d %H:%M:%S GMT", timestamp)
         end
    end
end

