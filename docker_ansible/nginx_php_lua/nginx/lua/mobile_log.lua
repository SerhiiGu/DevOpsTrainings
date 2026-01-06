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

