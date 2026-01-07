import requests
import pytest
import time
import json

def test_cache_logic(config, lua_allowed_uris):
    base_url = f"{config['scheme']}://{config['host']}:{config['port']}"
    
    print("\n" + "="*120)
    print(f"{'URI':<15} | {'STATUS':<8} | {'TTL':<8} | {'TIME':<8} | {'FULL URL':<30} | {'JSON_POST'}")
    print("-" * 120)

    for uri, post_data, expected_status in config['test_cases']:
        url = f"{base_url}{uri}"
        headers = {'Content-Type': 'application/json'}
        payload = json.loads(post_data)

        # 1. First request (should be MISS/BYPASS)
        r1 = requests.post(url, json=payload, verify=config['verify_ssl'], timeout=5)

        time.sleep(0.5)

        # 2. Second request (we tested this)
        start_time = time.time()
        r2 = requests.post(url, json=payload, verify=config['verify_ssl'], timeout=5)
        duration = time.time() - start_time

        # Get the data from the headers
        actual_status = r2.headers.get("X-Cache-Status", "NONE")
        ttl = r2.headers.get("X-Cache-Expires-In", "N/A")

        # Console output
        print(f"{uri:<15} | {actual_status:<8} | {ttl:<8} | {duration:.4f}s | {url:<30} | {payload}")

        # CHECKS
        # 1. Status (from the test_config.py)
        assert actual_status == expected_status, f"Wrong cache status for {uri}. Expected {expected_status}, got {actual_status}"

    print("="*110)

