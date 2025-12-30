import pytest
import time

def test_configs_output_format(run_cmd, cleanup_vm):
    """Перевірка детальної конфігурації у таблиці configs"""
    vm_name = cleanup_vm("test-info-vm")
    iso_name = "test-debian.iso"
    
    # Створюємо VM з конкретними параметрами
    run_cmd("create", "--name", vm_name, "--cpu", "3", "--ram", "512", "--iso", iso_name)
    
    result = run_cmd("configs")
    assert result.returncode == 0
    
    # Перевіряємо заголовки таблиці
    assert "VM NAME" in result.stdout
    assert "VNC_PORT" in result.stdout
    
    # Перевіряємо, чи дані в рядку відповідають заданим
    assert vm_name in result.stdout
    assert "3" in result.stdout
    assert "512" in result.stdout
    assert iso_name in result.stdout

def test_list_status_transitions(run_cmd, cleanup_vm):
    """Перевірка зміни статусу в команді list (STOPPED -> RUNNING)"""
    vm_name = cleanup_vm("test-list-vm")
    run_cmd("create", "--name", vm_name)
    
    # 1. Перевіряємо, що після створення статус STOPPED
    list_stopped = run_cmd("list")
    assert vm_name in list_stopped.stdout
    assert "[STOPPED]" in list_stopped.stdout
    
    # 2. Запускаємо
    run_cmd("start", "--name", vm_name)
    time.sleep(1) # Даємо час QEMU підняти сокет
    
    # 3. Перевіряємо, що статус змінився на RUNNING
    list_running = run_cmd("list")
    assert vm_name in list_running.stdout
    assert "[RUNNING]" in list_running.stdout

def test_list_disk_usage_display(run_cmd, cleanup_vm):
    """Перевірка відображення дискового простору"""
    vm_name = cleanup_vm("test-disk-vm")
    run_cmd("create", "--name", vm_name, "--size", "5") # 5GB
    
    result = run_cmd("list")
    assert "DISK USAGE" in result.stdout
    # На свіжоствореному qcow2 диску використання зазвичай 0.00 GB або близьке до того
    assert "GB" in result.stdout

