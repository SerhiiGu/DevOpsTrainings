-- Cache key creation logic
-- The list of allowed URIs is here

-- 1. MANDATORY HEADER CHECK
-- Check if the specific header exists and equals 200
local req_headers = ngx.req.get_headers()
local mobile_resp_code = req_headers["x-mobile-app-http-response-code"]

-- If header is missing or not "200" => BYPASS cache immediately
if not mobile_resp_code or mobile_resp_code ~= "200" then
    ngx.var.skip_cache = 1
    -- Stop execution here, we don't need to parse body or URI
    return
end

-- 2. URI CHECK LOGIC
-- List of allowed URIs for caching.
-- Value 'true' means enabled.
-- Supports wildcards at the end (e.g., "/product/*")
local allowed_uris = {
    ["/"] = true,
    ["/lang-list"] = true,
    ["/about"] = true,
    ["/home"] = true,
    ["/product/*"] = true
}

local uri = ngx.var.uri
local is_uri_allowed = false

-- Check exact match first
if allowed_uris[uri] then
    is_uri_allowed = true
else
    -- Check wildcards
    for path, _ in pairs(allowed_uris) do
        -- Check if path ends with *
        if string.sub(path, -1) == "*" then
            -- Remove * to get the prefix (e.g., "/product/")
            local prefix = string.sub(path, 1, -2)
            -- Check if current URI starts with this prefix
            if string.sub(uri, 1, #prefix) == prefix then
                is_uri_allowed = true
                break
            end
        end
    end
end


-- If URI isn't allowed - skip all other checks
if not is_uri_allowed then
    ngx.var.skip_cache = 1

else
    local body = ngx.req.get_body_data()

    -- If the body is empty (ex.: empty POST)
    if not body or body == "" then
        ngx.var.my_cache_key = "json_empty"
    else
        local cjson = require "cjson"
        local status, data = pcall(cjson.decode, body)

        -- If the JSON is not valid => skip cache
        if not status or type(data) ~= "table" then
            ngx.var.skip_cache = 1
        else
            -- Use ALL fields from JSON for the key
            local sorted_keys = {}

	    for k, v in pairs(data) do
                table.insert(sorted_keys, k)
            end

            -- Make stable key
            table.sort(sorted_keys)
            local key_parts = {}

	    for _, k in ipairs(sorted_keys) do
                -- Handle different value types to avoid concatenation errors
                local val = data[k]
                if type(val) == "boolean" then
                    val = val and "true" or "false"
                elseif type(val) == "table" then
                    val = "table" -- Simplified for nested tables, or use cjson.encode(val) if deep key needed
                else
                    val = tostring(val)
                end

		table.insert(key_parts, k .. "=" .. val)
            end

            ngx.var.my_cache_key = table.concat(key_parts, ":")

            if ngx.var.my_cache_key == "" then
                ngx.var.my_cache_key = "json_empty"
            end
        end
    end
end

-- Final full key construction
ngx.var.full_key = ngx.var.scheme .. ngx.var.request_method .. ngx.var.host .. ngx.var.request_uri .. "|" .. ngx.var.my_cache_key
