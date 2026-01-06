import requests
import random
import string
import pytest

def get_random_str(length=8):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def generate_random_json(allowed_keys):
    count = random.randint(0, min(3, len(allowed_keys)))
    keys = random.sample(allowed_keys, count)
    return {k: get_random_str() for k in keys}

# --- БАЗОВИЙ ТЕСТ 1: Динамічні URI ---
def test_dynamic_uri_cache(config, lua_data):
    base_url = f"{config['scheme']}://{config['host']}:{config['port']}"
    # Фільтруємо URI: лишаємо тільки ті, яких нема в списку виключень
    test_uris = [u for u in lua_data['uris'] if u not in config['static_uri_excludes']]
    
    responses_bodies = {}

    for uri in test_uris:
        payload = generate_random_json(lua_data['keys'])
        url = f"{base_url}{uri}"
        
        # Перший запит (MISS)
        requests.post(url, json=payload, verify=config['verify_ssl'])
        
        # Другий запит (Перевірка HIT)
        r2 = requests.post(url, json=payload, verify=config['verify_ssl'])
        
        assert r2.headers.get("X-Cache-Status") == "HIT", f"URI {uri} failed HIT"
        responses_bodies[uri] = r2.text

    # Перевірка що тіла різні для різних URI
    assert len(set(responses_bodies.values())) == len(responses_bodies), "Bodies for different URIs must be unique"


# --- БАЗОВИЙ ТЕСТ 2: Статичні URI (Excludes) ---
def test_static_uri_cache(config, lua_data):
    base_url = f"{config['scheme']}://{config['host']}:{config['port']}"
    test_uris = config['static_uri_excludes']
    
    for uri in test_uris:
        url = f"{base_url}{uri}"
        
        # Робимо 2 запити з РІЗНИМИ тілами
        payload1 = {"test": "first"}
        payload2 = {"test": "second"}
        
        requests.post(url, json=payload1, verify=config['verify_ssl'])
        r2 = requests.post(url, json=payload2, verify=config['verify_ssl'])
        
        # Перевірки
        assert r2.headers.get("X-Cache-Status") == "HIT"
        # Тіла мають бути однаковими (бо ключ кешу для цих URI ігнорує POST)
        r1 = requests.post(url, json=payload1, verify=config['verify_ssl'])
        assert r1.text == r2.text
        
        # Перевірка TTL (X-Cache-Expires-In)
        # Оскільки ви вказали 1800 (30хв), перевіряємо відхилення
        ttl = r2.headers.get("X-Cache-Expires-In")
        if ttl:
            ttl_val = int(ttl.replace('s', ''))
            assert abs(ttl_val - 1800) <= 10, f"TTL for {uri} is {ttl_val}, expected ~1800"


# --- БАЗОВИЙ ТЕСТ 3: Рандомний URI (BYPASS) ---
def test_random_uri_bypass(config):
    base_url = f"{config['scheme']}://{config['host']}:{config['port']}"
    random_uri = f"/{get_random_str()}"
    url = f"{base_url}{random_uri}"
    
    r1 = requests.post(url, json={}, verify=config['verify_ssl'])
    # Навіть після першого запиту статус має бути BYPASS (немає в білому списку Lua)
    assert r1.headers.get("X-Cache-Status") == "BYPASS"
    
    r2 = requests.post(url, json={}, verify=config['verify_ssl'])
    assert r2.headers.get("X-Cache-Status") == "BYPASS"

