-- Get 1000 records from the LUA table

local cjson = require "cjson"
local cjson_safe = require "cjson.safe"
local cache_index = ngx.shared.cache_index

local limited_keys = cache_index:get_keys(1000)

local index_data = {}
for _, uri in ipairs(limited_keys) do
    local paths_str = cache_index:get(uri)
    local paths = {}
    if paths_str then
        for path in string.gmatch(paths_str, '([^,]+)') do
            table.insert(paths, path)
        end
    end
    index_data[uri] = paths
end

local response = {
    showing_limit = 1000,
    index = index_data
}

cjson.encode_sparse_array(true)
ngx.say(require("cjson").encode(response))

