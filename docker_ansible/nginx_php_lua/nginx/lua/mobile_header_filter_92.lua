-- Get technical status and our skip_save flag
local status = ngx.var.upstream_cache_status
local skip_save = ngx.var.skip_save

-- Logical status override:
-- If Nginx says MISS/EXPIRED but backend denied caching (skip_save=1), 
-- we force the header to show BYPASS for clarity.
if (status == "MISS" or status == "EXPIRED" or status == "STALE") and skip_save == "1" then
    ngx.header["X-Cache-Status"] = "BYPASS"
end

-- TTL Logic for HIT status
if status == "HIT" then
    local key = ngx.var.full_key
    local hash = ngx.md5(key)
    local path = "/var/cache/nginx/" .. string.sub(hash, -2) .. "/" .. string.sub(hash, -4, -3) .. "/" .. hash

    local f = io.open(path, "rb")
    if f then
        -- Nginx cache file header contains the expire timestamp at offset 8
        f:seek("set", 8)
        local bytes = f:read(8)
        f:close()

        if bytes and #bytes == 8 then
            local b1, b2, b3, b4, b5, b6, b7, b8 = string.byte(bytes, 1, 8)
            -- Convert 8 bytes to timestamp (little-endian)
            local timestamp = b1 + b2*256 + b3*65536 + b4*16777216

            local age = timestamp - ngx.time()
            ngx.header["X-Cache-Expires-In"] = age .. "s"
            ngx.header["X-Cache-Expires-At"] = os.date("!%Y-%m-%d %H:%M:%S GMT", timestamp)
        end
    end
end
