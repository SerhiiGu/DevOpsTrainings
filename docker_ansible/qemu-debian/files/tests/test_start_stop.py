import time
import pytest

def test_vm_start_lifecycle(run_cmd, cleanup_vm):
    """Повний цикл: Створення -> Запуск -> Перевірка -> Зупинка"""
    vm_name = cleanup_vm("test-start-vm")
    
    # 1. Підготовка (створюємо VM)
    run_cmd("create", "--name", vm_name, "--ram", "512")
    
    # 2. Запуск
    start_res = run_cmd("start", "--name", vm_name)
    assert start_res.returncode == 0
    assert "started" in start_res.stdout
    
    # Дамо QEMU секунду розкочегаритися
    time.sleep(1)
    
    list_res = run_cmd("list")
    # Припускаємо, що list виводить [RUNNING] або просто ім'я запущеної VM
    assert vm_name in list_res.stdout
    assert "RUNNING" in list_res.stdout

def test_start_already_running_vm(run_cmd, cleanup_vm):
    """Перевірка спроби запуску вже працюючої машини"""
    vm_name = cleanup_vm("test-double-start")
    run_cmd("create", "--name", vm_name)
    run_cmd("start", "--name", vm_name)
    
    # Спробуємо запустити вдруге
    result = run_cmd("start", "--name", vm_name)
    
    # Твій код просто робить return, тому returncode буде 0
    assert result.returncode == 0
    assert "already running" in result.stdout

def test_stop_vm_poweroff(run_cmd, cleanup_vm):
    """Перевірка зупинки в режимі poweroff"""
    vm_name = cleanup_vm("test-stop-vm")
    run_cmd("create", "--name", vm_name)
    run_cmd("start", "--name", vm_name)
    
    time.sleep(1) # Чекаємо запуску
    
    # Зупиняємо
    stop_res = run_cmd("stop", "--name", vm_name, "--mode", "poweroff")
    assert stop_res.returncode == 0
    
    # Перевіряємо, що в списку вона тепер [STOPPED]
    list_res = run_cmd("list")
    assert vm_name in list_res.stdout
    assert "STOPPED" in list_res.stdout

def test_stop_non_existent_vm(run_cmd):
    """Спроба зупинити те, чого немає"""
    result = run_cmd("stop", "--name", "ghost-vm", "--mode", "poweroff")
    
    # Якщо твій load_vm кидає помилку або виходить, тут буде != 0
    assert result.returncode != 0

