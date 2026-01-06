local stats = ngx.shared.cache_stats
local hit = tonumber(stats:get("TOTAL_HIT") or 0)
local miss = tonumber(stats:get("TOTAL_MISS") or 0)
local bypass = tonumber(stats:get("TOTAL_BYPASS") or 0)

local total = hit + miss + bypass

local hit_p, miss_p, bypass_p = 0, 0, 0
if total > 0 then
    hit_p = (hit / total) * 100
    miss_p = (miss / total) * 100
    bypass_p = (bypass / total) * 100
end

local res = string.format(
    "HIT:            %-10d %.3f%%\n" ..
    "MISS_EXPIRED:   %-10d %.3f%%\n" ..
    "BYPASS:         %-10d %.3f%%\n" ..
    "-----------------------------------\n" ..
    "TOTAL:          %d",
    hit, hit_p, miss, miss_p, bypass, bypass_p, total
)
ngx.say(res)

