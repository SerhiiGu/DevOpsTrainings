import os
import pytest
import time

def test_delete_stopped_vm(run_cmd):
    """Тест видалення зупиненої VM"""
    vm_name = "test-delete-stopped"
    # Створюємо
    run_cmd("create", "--name", vm_name, "--size", "1")
    
    # Видаляємо (передаємо 'y' для підтвердження)
    result = run_cmd("delete", "--name", vm_name, "-f")
    
    assert result.returncode == 0
    assert "data have been removed" in result.stdout
    
    # Перевіряємо, що в списку її більше немає
    list_res = run_cmd("list")
    assert vm_name not in list_res.stdout

def test_delete_running_vm_auto_stop(run_cmd):
    """Тест видалення запущеної VM (має спрацювати авто-стоп)"""
    vm_name = "test-delete-running"
    run_cmd("create", "--name", vm_name, "--size", "1")
    run_cmd("start", "--name", vm_name)
    
    time.sleep(1) # Даємо час запуститися
    
    # Видаляємо запущену
    result = run_cmd("delete", "--name", vm_name, "-f")
    
    assert result.returncode == 0
    assert "is running. Sending poweroff signal" in result.stdout
    assert "data have been removed" in result.stdout

def test_delete_non_existent_vm(run_cmd):
    """Тест видалення неіснуючої VM (має бути exit code 1)"""
    result = run_cmd("delete", "--name", "non-existent-box")
    
    assert result.returncode == 1
    assert "does not exist" in result.stdout

def test_delete_cancel_by_user(run_cmd):
    """Тест відміни видалення користувачем (натиснули 'n')"""
    vm_name = "test-delete-cancel"
    run_cmd("create", "--name", vm_name, "--size", "1")
    
    result = run_cmd("delete", "--name", vm_name)
    
    # Перевіряємо, що файл конфігу все ще на місці
    list_res = run_cmd("list")
    assert vm_name in list_res.stdout
    
    # Підчищаємо за собою вручну, щоб не смітити
    run_cmd("delete", "--name", vm_name, "-f")

