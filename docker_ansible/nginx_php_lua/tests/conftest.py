import pytest
import requests
import yaml
import re

@pytest.fixture(scope="session")
def config():
    with open("test_config.yaml", "r") as f:
        return yaml.safe_load(f)

@pytest.fixture(scope="session")
def lua_allowed_uris():
    """Parse allowed_uris from Lua"""
    lua_path = "/etc/nginx/lua/mobile_rewrite_logic.lua"
    with open(lua_path, "r") as f:
        content = f.read()
    
    # Regexp for getting ["/uri"] = { keys }
    uri_blocks = re.findall(r'\["(.*?)"\]\s*=\s*\{(.*?)\}', content, re.DOTALL)
    
    parsed = {}
    for uri, keys_str in uri_blocks:
        # Get key names
        keys = re.findall(r'(\w+)\s*=\s*true', keys_str)
        parsed[uri] = keys
    return parsed

@pytest.fixture(autouse=True)
def purge_cache(config):
    """Full cache clean before tests"""
    base_url = f"{config['scheme']}://{config['host']}:{config['port']}"
    requests.post(f"{base_url}/purge_cache", json={"pages": ["/"]}, timeout=5)
    requests.post(f"{base_url}/purge_cache_lua_table", json={"pages": ["*"]}, timeout=5)
