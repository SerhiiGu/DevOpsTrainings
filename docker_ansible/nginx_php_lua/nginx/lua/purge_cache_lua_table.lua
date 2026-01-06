local cjson = require "cjson.safe"
local cache_index = ngx.shared.cache_index
local body = ngx.var.request_body

if not body or body == "" then
    ngx.status = 400
    ngx.say("Error: Empty request body. Expected {'pages': ['/uri1', '/uri2*', '*']}")
    return
end

local data = cjson.decode(body)

if not data or type(data.pages) ~= "table" then
    ngx.status = 400
    ngx.say("Error: Invalid format. Expected {'pages': ['/uri1', '/uri2*', '*']}")
    return
end

-- Inner function, called later: Delete cache files with exact URI
local function purge_uri(uri)
    local deleted = 0
    local paths_str = cache_index:get(uri)
    if paths_str then
        for path in string.gmatch(paths_str, '([^,]+)') do
            if os.remove(path) then
                deleted = deleted + 1
            end
        end
        cache_index:delete(uri)
    end
    return deleted
end

local deleted_total = 0
local all_keys = nil

for _, pattern in ipairs(data.pages) do
    if string.sub(pattern, -1) == "*" then
        -- wildcard logic (ex.: /path/*)
        local prefix = string.sub(pattern, 1, -2) -- remove asterisk

        if not all_keys then all_keys = cache_index:get_keys(0) end

        for _, uri in ipairs(all_keys) do
            -- Check if URI start with prefix
            if string.sub(uri, 1, #prefix) == prefix then
                deleted_total = deleted_total + purge_uri(uri)
            end
        end
    else
        -- Counting removed pages
        deleted_total = deleted_total + purge_uri(pattern)
    end
end

ngx.say("Success: Purge finished. Deleted files: " .. deleted_total)

