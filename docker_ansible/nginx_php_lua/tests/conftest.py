import pytest
import requests
import re
import yaml
import os

@pytest.fixture(scope="session")
def config():
    with open("test_config.yaml", "r") as f:
        return yaml.safe_load(f)

@pytest.fixture(scope="session")
def lua_data():
    lua_path = "/etc/nginx/lua/mobile_rewrite_logic.lua"
    with open(lua_path, "r") as f:
        content = f.read()
    
    # Витягуємо allowed_keys
    keys_match = re.search(r"allowed_keys\s*=\s*\{(.*?)\}", content, re.DOTALL)
    allowed_keys = re.findall(r"(\w+)\s*=\s*true", keys_match.group(1)) if keys_match else []

    # Витягуємо allowed_uris
    uris_match = re.search(r"allowed_uris\s*=\s*\{(.*?)\}", content, re.DOTALL)
    allowed_uris = re.findall(r'\["(.*?)"\]', uris_match.group(1)) if uris_match else []
    
    return {"keys": allowed_keys, "uris": allowed_uris}

@pytest.fixture(autouse=True)
def purge_cache(config):
    """Очищення кешу перед кожним тестом"""
    base_url = f"{config['scheme']}://{config['host']}:{config['port']}"
    payload = {"pages": ["*"]}
    
    requests.post(f"{base_url}/purge_cache", json=payload, verify=config['verify_ssl'])
    requests.post(f"{base_url}/purge_cache_lua_table", json=payload, verify=config['verify_ssl'])

