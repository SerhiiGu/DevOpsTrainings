-- Cache key creation logic
-- The list of allowed URIs for caching.
-- Logic: If URI matches (exact or wildcard), we proceed to body parsing.

local allowed_uris = {
    ["/"] = true,
    ["/lang-list"] = true,
    ["/about"] = true,
    ["/home"] = true,
    ["/common-data"] = true,
    ["/product/*"] = true
}

local uri = ngx.var.uri
local is_uri_allowed = false

-- remove gzip from nginx=>PHP headers (always UNcompressed data to client)
--ngx.req.clear_header("Accept-Encoding")

-- 1. Check URI allowlist (Exact match first, then Wildcard)
if allowed_uris[uri] then
    is_uri_allowed = true
else
    -- Wildcard check
    for path, _ in pairs(allowed_uris) do
        if string.sub(path, -1) == "*" then
            local prefix = string.sub(path, 1, -2) -- Remove *
            -- Check if URI starts with prefix
            if string.sub(uri, 1, #prefix) == prefix then
                is_uri_allowed = true
                break
            end
        end
    end
end

-- 2. Processing
if not is_uri_allowed then
    -- URI not allowed -> Skip cache immediately
    ngx.var.skip_cache = 1

else
    -- Standard JSON body parsing
    local body = ngx.req.get_body_data()

    if not body or body == "" then
        -- Empty body -> specific key
        ngx.var.my_cache_key = "json_empty"
    else
        local cjson = require "cjson"
        local status, data = pcall(cjson.decode, body)

        -- Invalid JSON -> Skip cache
        if not status or type(data) ~= "table" then
            ngx.var.skip_cache = 1
        else
            -- Use ALL fields from JSON to build the key
            local sorted_keys = {}
            for k, v in pairs(data) do
                table.insert(sorted_keys, k)
            end

            table.sort(sorted_keys)

	    local key_parts = {}
            for _, k in ipairs(sorted_keys) do
                local val = data[k]
                -- Simple normalization for key stability
                if type(val) == "boolean" then
                    val = val and "true" or "false"
                elseif type(val) == "table" then
                    val = "table" -- Or use recursive dump if needed
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

-- Final key construction
ngx.var.full_key = ngx.var.scheme .. ngx.var.request_method .. ngx.var.host .. ngx.var.request_uri .. "|" .. ngx.var.my_cache_key

-- Generate MD5 hash for the filename(for logging)
ngx.var.cache_file_md5 = ngx.md5(ngx.var.full_key)
