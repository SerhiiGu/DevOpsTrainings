-- Header Filter Logic
-- Handles Cache-Control based on backend response AND manages visual Cache Status

local upstream_status = ngx.var.upstream_cache_status
local final_status = upstream_status

-- 1. Check backend response for validity (Only if we touched backend)
if upstream_status == "MISS" or upstream_status == "STALE" or upstream_status == "EXPIRED" or upstream_status == "BYPASS" then
    local resp_headers = ngx.resp.get_headers()
    local app_code = resp_headers["x-mobile-app-http-response-code"]

    -- If header is missing OR not "200"
    if not app_code or app_code ~= "200" then
        -- Prevent saving to cache
        ngx.var.skip_cache = 1
	-- VISUALLY report as BYPASS to the client
        final_status = "BYPASS"
    end
end

-- 2. Set the client-facing header manually (Because we removed add_header from nginx.conf)
--ngx.header["X-Cache-Status"] = final_status

-- 2. Set values for logging
ngx.var.lua_cache_status = final_status
ngx.var.mobile_app_response_code = app_code


-- Remove headers from client response
--ngx.header["x-mobile-app-http-response-code"] = nil
--ngx.header["X-Cache-Status"] = nil


-- skip all code below, it is needed only for debug
if true then
    return
end

-- 3. Calculate TTL for Cache Hits (Standard Logic)
if upstream_status == "HIT" then
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
