-- Cache key creation logic

local cjson = require "cjson"

-- Get request body
local body = ngx.req.get_body_data()

if not body or body == "" then
    -- If body is empty, use a default static key component
    ngx.var.my_cache_key = "json_empty"
else
    local status, data = pcall(cjson.decode, body)

    if not status or type(data) ~= "table" then
        -- Invalid JSON format - better bypass to be safe
        ngx.var.skip_cache = 1
        ngx.var.my_cache_key = "invalid_json"
    else
        -- Create stable key from all provided fields (no whitelist)
        local sorted_keys = {}
        for k in pairs(data) do
            table.insert(sorted_keys, k)
        end
        table.sort(sorted_keys)

        local key_parts = {}
        for _, k in ipairs(sorted_keys) do
            table.insert(key_parts, k .. "=" .. tostring(data[k]))
        end

        ngx.var.my_cache_key = table.concat(key_parts, ":")

        if ngx.var.my_cache_key == "" then
            ngx.var.my_cache_key = "json_empty"
        end
    end
end

-- Generate the final full cache key
ngx.var.full_key = ngx.var.scheme .. ngx.var.request_method .. ngx.var.host .. ngx.var.request_uri .. "|" .. ngx.var.my_cache_key
