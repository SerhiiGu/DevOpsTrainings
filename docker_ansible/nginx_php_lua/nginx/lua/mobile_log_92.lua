-- Block for /purge_cache_fast (purge logic)
-- cache indexing

local status = ngx.var.upstream_cache_status
local skip_save = ngx.var.skip_save -- Value from our Nginx map (0 = will save, 1 = skip)
local skip_cache = ngx.var.skip_cache -- Value from our Lua logic (1 = bypass)

-- INDEXING LOGIC
-- We should only index if it's a HIT (already there) 
-- OR if it's a MISS/EXPIRED/STALE and backend ALLOWED caching (skip_save == "0")
if skip_cache == "0" and (status == "HIT" or (status ~= "BYPASS" and skip_save == "0")) then
    if ngx.var.my_cache_key ~= "" then
        local cache_index = ngx.shared.cache_index

        -- Calculate cache path like Nginx (levels=2:2)
        local hash = ngx.md5(ngx.var.full_key)
        local path = "/var/cache/nginx/" .. string.sub(hash, -2) .. "/" .. string.sub(hash, -4, -3) .. "/" .. hash

        -- Update cache LUA table
        local existing = cache_index:get(ngx.var.uri) or ""
        if not string.find(existing, path, 1, true) then
            cache_index:set(ngx.var.uri, (existing == "" and path or existing .. "," .. path))
        end
    end
end

-- CACHE HIT/MISS COUNTING LOGIC
local stats = ngx.shared.cache_stats
local uri = ngx.var.uri

-- 1. HIT: Found in cache
if status == "HIT" then
    stats:incr(uri .. ":HIT", 1, 0)
    stats:incr("TOTAL_HIT", 1, 0)

-- 2. MISS/EXPIRED: Backend allowed caching, so this is a "valid" cache miss
elseif (status == "MISS" or status == "EXPIRED" or status == "STALE") and skip_save == "0" then
    stats:incr(uri .. ":MISS_EXPIRED", 1, 0)
    stats:incr("TOTAL_MISS", 1, 0)

-- 3. BYPASS: Everything else is a dynamic request
-- This includes status="BYPASS" AND status="MISS" where backend said "no cache" (skip_save == 1)
else
    stats:incr(uri .. ":BYPASS", 1, 0)
    stats:incr("TOTAL_BYPASS", 1, 0)
end
