import pytest
import subprocess
import os
import sys

# Фікстура для запуску команд менеджера
@pytest.fixture
def run_cmd():
    def _run(*args):
        # Використовуємо повний шлях до інтерпретатора та скрипта
        cmd = [sys.executable, "/usr/local/bin/qemu-manager.py"] + list(args)
        result = subprocess.run(cmd, capture_output=True, text=True)
        return result
    return _run

# Фікстура для автоматичного прибирання після тесту
@pytest.fixture
def cleanup_vm(run_cmd):
    created_vms = []
    
    def _register(name):
        created_vms.append(name)
        return name
        
    yield _register # Тут виконується сам тест

    # --- ЕТАП ОЧИСТКИ ---
    # Отримуємо список запущених машин один раз перед циклом
    running_vms_output = run_cmd("list").stdout

    for vm in created_vms:
        # 1. Зупиняємо, ТІЛЬКИ якщо вона запущена
        if vm in running_vms_output:
            run_cmd("stop", "--name", vm, "--mode", "poweroff")

        # 2. Видаляємо VM (команда delete видалить і конфіг, і диски, якщо передбачено)
        # Робимо це для кожної зареєстрованої VM, незалежно від того, чи пройшов тест
        run_cmd("delete", "--name", vm, "-f")
