-- Get total number of the cache keys in the LUA table

local cache_index = ngx.shared.cache_index
local all_keys = cache_index:get_keys(0)

local total_files = 0
local total_uris = #all_keys

for _, uri in ipairs(all_keys) do
    local paths_str = cache_index:get(uri)
    if paths_str then
        -- Count comma separated paths in the row (every path start with /var/cache/nginx, so, just count of includes)
        local _, count = string.gsub(paths_str, "/var/cache/nginx", "")
        total_files = total_files + count
    end
end

local response = {
    total_unique_uris = total_uris,
    total_cache_files = total_files
}

local cjson = require "cjson"
ngx.say(cjson.encode(response))

