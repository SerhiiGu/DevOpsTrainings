import json
import os

# Шлях до конфігів (перевір, чи він такий у тебе)
CONFIG_PATH = "/root/.config/qemu-manager/vms"

def test_modify_ram_and_cpu(run_cmd, cleanup_vm):
    """Перевірка зміни RAM та CPU"""
    vm_name = cleanup_vm("test-modify-vm")
    run_cmd("create", "--name", vm_name, "--ram", "512", "--cpu", "1")
    
    # Модифікуємо
    modify_res = run_cmd("modify", "--name", vm_name, "--ram", "2048", "--cpu", "4")
    assert modify_res.returncode == 0
    
    # Перевіряємо вміст JSON файлу
    with open(f"{CONFIG_PATH}/{vm_name}.json", "r") as f:
        data = json.load(f)
        assert data["ram"] == 2048
        assert data["cpu"] == 4

def test_modify_non_existent_vm(run_cmd):
    """Спроба змінити параметри неіснуючої VM"""
    result = run_cmd("modify", "--name", "ghost-vm", "--ram", "1024")
    assert result.returncode != 0
    assert "not found" in result.stdout or "not found" in result.stderr

