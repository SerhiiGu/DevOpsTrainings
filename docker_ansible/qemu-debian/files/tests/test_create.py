import pytest
import os

def test_create_minimal_vm(run_cmd, cleanup_vm):
    """Тест створення VM з мінімальними параметрами"""
    vm_name = cleanup_vm("test-min-vm")
    result = run_cmd("create", "--name", vm_name)
    
    assert result.returncode == 0
    assert f"VM {vm_name} created" in result.stdout


def test_create_full_vm(run_cmd, cleanup_vm):
    """Тест створення VM з усіма можливими прапорцями"""
    vm_name = cleanup_vm("test-full-vm")
    result = run_cmd("create", 
                     "--name", vm_name, 
                     "--ram", "1111", 
                     "--cpu", "1", 
                     "--net", "bridge",
                     "--vnc", "5905")
    
    assert result.returncode == 0

    # Перевіряємо, чи вона з'явилася в списку (команда list)
    list_res = run_cmd("list")
    assert vm_name in list_res.stdout


def test_create_duplicate_name(run_cmd, cleanup_vm):
    """Перевірка, що не можна створити VM з однаковим ім'ям"""
    vm_name = cleanup_vm("duplicate-vm")
    run_cmd("create", "--name", vm_name) # Перший раз
    result = run_cmd("create", "--name", vm_name) # Другий раз
    
    assert result.returncode != 0
    assert "already exists" in result.stdout


def test_create_invalid_vnc(run_cmd, cleanup_vm):
    """Тест на некоректний VNC порт (менше 5901)"""
    vm_name = cleanup_vm("invalid-vnc-vm")
    result = run_cmd("create", "--name", vm_name, "--vnc", "not-a-number")
    
    # Оскільки ми вирішили НЕ зупиняти скрипт, returncode буде 0
    assert result.returncode == 0
    # Перевіряємо, що користувача попередили
    assert "Warning: Invalid VNC port" in result.stdout
    # Перевіряємо, що VM все одно створилася
    assert "created successfully" in result.stdout


def test_create_without_name(run_cmd):
    """Перевірка обов'язковості аргументу --name"""
    result = run_cmd("create")
    
    assert result.returncode != 0
    assert "the following arguments are required: --name" in result.stderr

