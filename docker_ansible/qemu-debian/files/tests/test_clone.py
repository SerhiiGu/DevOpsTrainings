import os
import pytest
import time

def test_clone_success(run_cmd, cleanup_vm):
    """Тест успішного клонування зупиненої VM"""
    old_vm = cleanup_vm("source-vm")
    new_vm = cleanup_vm("cloned-vm")

    # 1. Створюємо джерело
    run_cmd("create", "--name", old_vm, "--ram", "1024", "--vnc", "5901")
    
    # 2. Клонуємо
    result = run_cmd("clone", "--name", old_vm, "--new_name", new_vm)
    assert result.returncode == 0
    assert "successfully cloned" in result.stdout

    # 3. Перевіряємо чи існує новий конфіг та диск
    configs = run_cmd("configs")
    assert new_vm in configs.stdout
    
    # 4. Перевіряємо, що VNC у клона вимкнено (як у твоєму коді vm['vnc'] = 'none')
    # Шукаємо рядок з клонованою VM
    vm_line = [l for l in configs.stdout.splitlines() if new_vm in l][0]
    assert "off" in vm_line or "none" in vm_line

def test_clone_error_already_exists(run_cmd, cleanup_vm):
    """Тест: не можна клонувати, якщо ім'я нового конфігу вже зайняте"""
    old_vm = cleanup_vm("source-exists")
    existing_vm = cleanup_vm("already-here")

    run_cmd("create", "--name", old_vm)
    run_cmd("create", "--name", existing_vm)

    # Намагаємось клонувати в ім'я, яке вже існує
    result = run_cmd("clone", "--name", old_vm, "--new_name", existing_vm)
    assert "already exists" in result.stdout
    # У твоєму коді немає sys.exit(1) після return, тому перевір, чи треба додати його

def test_clone_error_running_vm(run_cmd, cleanup_vm):
    """Тест: заборона клонування запущеної машини"""
    vm_name = cleanup_vm("running-src")
    dest_name = cleanup_vm("dest-vm")

    run_cmd("create", "--name", vm_name)
    run_cmd("start", "--name", vm_name)
    time.sleep(1)

    result = run_cmd("clone", "--name", vm_name, "--new_name", dest_name)
    assert "Cannot clone a running VM" in result.stdout
    
    # Перевіряємо, що клон НЕ створився
    configs = run_cmd("configs")
    assert dest_name not in configs.stdout

