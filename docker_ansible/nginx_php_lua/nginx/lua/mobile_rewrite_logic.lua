-- Cache key creation logic
-- The list of allowed URI and the list of allowed fields is here


-- List of allowed URIs for caching
local allowed_uris = {
    ["/"] = true,
    ["/lang_list"] = true,
    ["/about"] = true,
    ["/home"] = true
}

-- If URI isn't allowed - skip all other checks
if not allowed_uris[ngx.var.uri] then
    ngx.var.skip_cache = 1
-- For /lang_list => ignore POST data and cache without it
elseif ngx.var.uri == "/lang_list" then
    ngx.var.my_cache_key = "static_uri_cache"
else
    local body = ngx.req.get_body_data()

    -- If the body is empty (ex.: empty POST) - set the cache key as json_empty
    if not body or body == "" then
        ngx.var.my_cache_key = "json_empty"
    else
        local cjson = require "cjson"
        local status, data = pcall(cjson.decode, body)

        -- If the JSON is not valid => skip cache
        if not status or type(data) ~= "table" then
            ngx.var.skip_cache = 1
        else
            -- Allowed fields list
            local allowed_keys = { lang = true, regionId = true, currencyCodeString = true, page = true, valid = true }
            local sorted_keys = {}
            local invalid_found = false

            for k, v in pairs(data) do
                if not allowed_keys[k] then
                    invalid_found = true
                    break
                end
                table.insert(sorted_keys, k)
            end

            if invalid_found then
                -- Fount not allowed field => skip cache
                ngx.var.skip_cache = 1
            else
                -- Make stable key
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
    end
end
ngx.var.full_key = ngx.var.scheme .. ngx.var.request_method .. ngx.var.host .. ngx.var.request_uri .. "|" .. ngx.var.my_cache_key

