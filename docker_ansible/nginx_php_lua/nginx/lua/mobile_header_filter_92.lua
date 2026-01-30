-- Get technical status from Nginx and our save flag
local status = ngx.var.upstream_cache_status
local skip_save = ngx.var.skip_save
local final_status = status

-- Override logic:
-- If it's technically a MISS but backend denied saving, call it BYPASS
if (status == "MISS" or status == "EXPIRED" or status == "STALE") and skip_save == "1" then
    final_status = "BYPASS"
end

-- IMPORTANT: Always set the header since we removed 'add_header' from nginx.conf
-- If status is nil (very rare), default to "-"
ngx.header["X-Cache-Status"] = final_status or "-"

-- TTL Logic for HIT status (extracting info from Nginx cache file)
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
