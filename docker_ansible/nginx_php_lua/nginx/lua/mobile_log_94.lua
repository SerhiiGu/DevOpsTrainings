-- Block for /purge_cache_fast (purge logic)
-- cache indexing

if ngx.var.skip_cache == "0" and ngx.var.my_cache_key ~= "" then
    local cache_index = ngx.shared.cache_index

    -- Calculate cache like Nginx (levels=2:2)
    local hash = ngx.md5(ngx.var.full_key)
    local path = "/var/cache/nginx/" .. string.sub(hash, -2) .. "/" .. string.sub(hash, -4, -3) .. "/" .. hash

    -- Update cache LUA table (works with HIT and MISS)
    local existing = cache_index:get(ngx.var.uri) or ""
    if not string.find(existing, path, 1, true) then
        cache_index:set(ngx.var.uri, (existing == "" and path or existing .. "," .. path))
    end
end

-- Cache HIT/MISS counting
local stats = ngx.shared.cache_stats
local status = ngx.var.lua_cache_status
local uri = ngx.var.uri

-- HIT
if status == "HIT" or status == "UPDATING" then
    stats:incr(uri .. ":HIT", 1, 0) -- Detailed counter, for every URI
    stats:incr("TOTAL_HIT", 1, 0)   -- Global counter

-- MISS + EXPIRED
elseif (status == "MISS" or status == "EXPIRED" or status == "STALE") and ngx.var.skip_cache == "0" then
    stats:incr(uri .. ":MISS_EXPIRED", 1, 0)
    stats:incr("TOTAL_MISS", 1, 0)

-- BYPASS (when skip_cache = 1)
elseif status == "BYPASS" or not status or status == "-" then
    stats:incr(uri .. ":BYPASS", 1, 0)
    stats:incr("TOTAL_BYPASS", 1, 0)
end

