-- Header Filter Logic
-- 1. Check if we should SAVE to cache based on backend response header.
-- 2. Calculate TTL if it is a HIT.

local upstream_status = ngx.var.upstream_cache_status

-- LOGIC 1: Validate Backend Response for Caching
-- We only check this if it's NOT a HIT (meaning we just got fresh data from PHP)
if upstream_status ~= "HIT" then
    local resp_headers = ngx.resp.get_headers()
    local app_code = resp_headers["x-mobile-app-http-response-code"]

    -- If header is missing OR not "200", DO NOT SAVE to cache
    if not app_code or app_code ~= "200" then
        ngx.var.skip_cache = 1
    end
end

-- LOGIC 2: Calculate TTL for Cache Hits (Existing logic)
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

