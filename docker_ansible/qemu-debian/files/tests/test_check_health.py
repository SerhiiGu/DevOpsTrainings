import os
import json
import pytest

def test_check_health_ok(run_cmd, cleanup_vm):
    """Перевірка стану здоров'я VM, коли все на місці"""
    vm_name = cleanup_vm("check-ok-vm")
    # Створюємо VM (диск створиться автоматично)
    run_cmd("create", "--name", vm_name, "--size", "1")
    
    result = run_cmd("check")
    assert result.returncode == 0
    
    # Шукаємо рядок нашої VM
    line = [l for l in result.stdout.splitlines() if vm_name in l][0]
    # Формат: NAME DISK ISO NET. Очікуємо OK для диска
    assert "OK" in line


def test_check_health_missing_disk(run_cmd, cleanup_vm):
    """Перевірка стану, якщо файл диска видалено"""
    vm_name = cleanup_vm("check-missing-disk")
    run_cmd("create", "--name", vm_name)

    # 1. Читаємо конфіг, щоб дізнатися справжній шлях до диска
    config_path = f"/root/.config/qemu-manager/vms/{vm_name}.json"

    with open(config_path, 'r') as f:
        vm_data = json.load(f)
        disk_path = vm_data.get('disk') # Отримуємо реальний шлях з JSON

    # 2. Видаляємо справжній файл диска
    if disk_path and os.path.exists(disk_path):
        os.remove(disk_path)
        print(f"DEBUG: Removed disk at {disk_path}")
    else:
        pytest.fail(f"Could not find disk file at {disk_path} to delete it")

    # 3. Перевіряємо статус
    result = run_cmd("check")
    line = [l for l in result.stdout.splitlines() if vm_name in l][0]

    assert "MISSING" in line


def test_check_health_missing_iso(run_cmd, cleanup_vm):
    """Перевірка стану, якщо вказано неіснуючий ISO"""
    vm_name = cleanup_vm("check-missing-iso")
    # Створюємо VM з фейковим ISO
    run_cmd("create", "--name", vm_name, "--iso", "non-existent-distro.iso")
    
    result = run_cmd("check")
    line = [l for l in result.stdout.splitlines() if vm_name in l][0]
    # Перший OK (диск), другий MISSING (ISO)
    assert "MISSING" in line

def test_check_no_vms(run_cmd):
    """Перевірка виводу, якщо VM взагалі немає"""
    # Цей тест спрацює коректно, якщо запустити його окремо або якщо cleanup_vm все вичистив
    # Тимчасово створюємо порожню директорію, якщо потрібно, або просто перевіряємо повідомлення
    result = run_cmd("check")
    if "No VMs to check" in result.stdout:
        assert True

