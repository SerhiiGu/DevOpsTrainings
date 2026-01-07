import requests
import pytest
import re
import json

# Helper for parsing JSON stats
def get_stats_json(config):
    url = f"{config['scheme']}://{config['host']}:{config['port']}/cache_show_stats"
    return requests.get(url, timeout=5).json()

# Helper for parsing text summary
def get_stats_summary(config):
    url = f"{config['scheme']}://{config['host']}:{config['port']}/cache_summary"
    r = requests.get(url, timeout=5)
    def parse(pattern, text):
        match = re.search(pattern, text)
        return int(match.group(1)) if match else 0
    return {
        "hit": parse(r"HIT:\s+(\d+)", r.text),
        "miss": parse(r"MISS_EXPIRED:\s+(\d+)", r.text),
        "bypass": parse(r"BYPASS:\s+(\d+)", r.text),
        "total": parse(r"TOTAL:\s+(\d+)", r.text)
    }

# --- Tests for /cache_show_stats ---
def test_stats_show_increment(config):
    base_url = f"{config['scheme']}://{config['host']}:{config['port']}"
    uri = "/home"
    url = f"{base_url}{uri}"
    payload = {"lang": "uk", "regionId": "2", "currencyCodeString": "UAH"}

    # Get stats BEFORE
    before = get_stats_json(config)
    b_uri_hit = before.get(f"{uri}:HIT", 0)
    b_total_hit = before.get("TOTAL_HIT", 0)

    # Run test (1 MISS + 1 HIT)
    requests.post(url, json=payload) # MISS
    requests.post(url, json=payload) # HIT

    # Get stats AFTER
    after = get_stats_json(config)
    a_uri_hit = after.get(f"{uri}:HIT", 0)
    a_total_hit = after.get("TOTAL_HIT", 0)

    print(f"\n[TEST SHOW_STATS] URL: {url}")
    print(f"  {uri}:HIT  | Before: {b_uri_hit:<4} | After: {a_uri_hit:<4} | Diff: {a_uri_hit - b_uri_hit}")
    print(f"  TOTAL_HIT | Before: {b_total_hit:<4} | After: {a_total_hit:<4} | Diff: {a_total_hit - b_total_hit}")

    assert a_uri_hit == b_uri_hit + 1
    assert a_total_hit == b_total_hit + 1


# --- Tests for /cache_summary ---
def test_stats_summary_increment(config):
    base_url = f"{config['scheme']}://{config['host']}:{config['port']}"
    
    # Prepare fot runs: we want to generate 1 BYPASS and 1 HIT (with 1 MISS before)
    uri_bypass = "/random_page"
    uri_hit = "/about"
    payload_hit = {"lang": "uk", "regionId": "1", "currencyCodeString": "UAH"}

    # Get stats BEFORE
    before = get_stats_summary(config)

    # Run test
    requests.post(f"{base_url}{uri_bypass}", json={}) # +1 BYPASS, +1 TOTAL
    requests.post(f"{base_url}{uri_hit}", json=payload_hit) # +1 MISS, +1 TOTAL
    requests.post(f"{base_url}{uri_hit}", json=payload_hit) # +1 HIT, +1 TOTAL

    # Get stats AFTER
    after = get_stats_summary(config)

    print(f"\n[TEST SUMMARY] Mixed actions (HIT/MISS/BYPASS)")
    print(f"  L_BYPASS: {uri_bypass} | L_HIT: {uri_hit}")
    print(f"  HIT       | Before: {before['hit']:<4} | After: {after['hit']:<4} | Diff: {after['hit'] - before['hit']}")
    print(f"  MISS      | Before: {before['miss']:<4} | After: {after['miss']:<4} | Diff: {after['miss'] - before['miss']}")
    print(f"  BYPASS    | Before: {before['bypass']:<4} | After: {after['bypass']:<4} | Diff: {after['bypass'] - before['bypass']}")
    print(f"  TOTAL     | Before: {before['total']:<4} | After: {after['total']:<4} | Diff: {after['total'] - before['total']}")

    assert after['bypass'] == before['bypass'] + 1
    assert after['hit'] == before['hit'] + 1
    assert after['miss'] == before['miss'] + 1
    assert after['total'] == before['total'] + 3

