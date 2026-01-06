local cjson = require "cjson"
local body = ngx.var.request_body
local data = cjson.decode(body)

if not data or not data.pages or type(data.pages) ~= "table" then
    ngx.status = 400
    ngx.say("Invalid JSON. Expected {'pages': ['/uri1', '/uri2']}")
    return
end

local cache_path = "/var/cache/nginx"
local total_deleted = 0

for _, uri_pattern in ipairs(data.pages) do
    -- Escaping URIs for security in the shell
    local safe_uri = uri_pattern:gsub("'", "'\\''")

    -- COMMAND: grep -rl - find files => tee - list for the files counting => xargs rm -f - remove these files
    local cmd = string.format("grep -rl '%s' %s | tee /tmp/purged_list | wc -l && xargs rm -f < /tmp/purged_list", safe_uri, cache_path)

    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()

    local count = tonumber(result) or 0
    total_deleted = total_deleted + count

    --ngx.log(ngx.ERR, "PURGE: Pattern: " .. uri_pattern .. " | Deleted: " .. count)
end

ngx.say("Purge command executed for " .. #data.pages .. " patterns." .. "Deleted " .. total_deleted .. " files")

