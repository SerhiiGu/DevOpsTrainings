#!/bin/bash

BASE_URL="http://192.168.1.91:94"
STATS_URL="http://192.168.1.91:94/cache_summary"

run_test() {
    local name=$1
    local url=$2
    local data=$3
    local expected_stat=$4

    echo -e "\n>>> TEST: $name"
    
    # 1. Get stats BEFORE
    local before=$(curl -s $STATS_URL | grep "$expected_stat" | awk '{print $2}' || echo 0)
    [ -z "$before" ] && before=0

    # 2. Run request
    local headers=$(curl -i -s -X POST -d "$data" "$BASE_URL$url")
docker logs nginx --tail 1

    # 3. Check hidden headers
    local h1=$(echo "$headers" | grep -i "x-mobile-app-http-response-code")
    local h2=$(echo "$headers" | grep -i "X-Cache-Status")
    
    echo -n "Headers: [${h1:-empty}] [${h2:-empty}] .. "

    # 4. Get stats AFTER
    sleep 0.5 # Wait for log
    local after=$(curl -s $STATS_URL | grep "$expected_stat" | awk '{print $2}' || echo 0)
    [ -z "$after" ] && after=0
    
    local diff=$((after - before))
    echo -n "Stat change ($expected_stat): $before -> $after (Diff: $diff) .. "
    
    if [ "$diff" -ge 1 ]; then
        echo -e "\e[32mPASS\e[0m"
    else
        echo -e "\e[31mFAIL: Stat didn't increase\e[0m"
    fi
}

# --- ТЕСТ КЕЙСИ ---
# 0. Clean ALL cache
curl -i -X POST -d '{"pages": ["/"]}' $BASE_URL/purge_cache 2>&1 | grep Purge

# 1. Normal HIT (run twice to get HIT)
run_test "Normal MISS" "/about" '{"lang":"en"}' "MISS"
run_test "Normal HIT" "/about" '{"lang":"en"}' "HIT"

# 2. Wildcard
run_test "Wildcard MISS" "/product/smth1" '{"view":"full"}' "MISS"
run_test "Wildcard HIT" "/product/smth1" '{"view":"full"}' "HIT"

# 3. Code 400 (Force Error) -> BYPASS
run_test "Force Error 400" "/about" '{"lang":"en", "force_error_code": true}' "BYPASS"

# 4. No Header -> BYPASS
run_test "Missing Header" "/about" '{"lang":"en", "simulate_missing_header": true}' "BYPASS"

# 5. Not allowed URI -> BYPASS
run_test "Not Allowed URI" "/contact-us" '{}' "BYPASS"

