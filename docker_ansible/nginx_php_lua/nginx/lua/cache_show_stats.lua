local stats = ngx.shared.cache_stats
local keys = stats:get_keys(0)

local res = {}
for _, key in ipairs(keys) do
    res[key] = stats:get(key)
end

local cjson = require "cjson"
ngx.say(cjson.encode(res))

