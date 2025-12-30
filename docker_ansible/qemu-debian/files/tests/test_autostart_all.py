import time
import pytest

def test_autostart_all_logic(run_cmd, cleanup_vm):
    """Перевірка масового автозапуску лише вибраних VM"""
    # 1. Створюємо три різні VM
    vm_auto1 = cleanup_vm("auto-1")
    vm_auto2 = cleanup_vm("auto-2")
    vm_manual = cleanup_vm("manual-only")

    run_cmd("create", "--name", vm_auto1)
    run_cmd("create", "--name", vm_auto2)
    run_cmd("create", "--name", vm_manual)

    # 2. Вмикаємо автозапуск тільки для перших двох
    run_cmd("enable_autostart", "--name", vm_auto1)
    run_cmd("enable_autostart", "--name", vm_auto2)

    # 3. Виконуємо команду autostart_all
    result = run_cmd("autostart_all")
    
    assert "Autostarting auto-1" in result.stdout
    assert "Autostarting auto-2" in result.stdout
    assert "Autostarting manual-only" not in result.stdout

    # Даємо час процесам QEMU ініціалізуватися
    time.sleep(2)

    # 4. Перевіряємо статуси через list
    list_res = run_cmd("list")
    assert f"{vm_auto1}" in list_res.stdout and "[RUNNING]" in list_res.stdout
    assert f"{vm_auto2}" in list_res.stdout and "[RUNNING]" in list_res.stdout
    assert f"{vm_manual}" in list_res.stdout and "[STOPPED]" in list_res.stdout

def test_autostart_all_skip_running(run_cmd, cleanup_vm):
    """Перевірка, що autostart_all не чіпає вже запущені машини"""
    vm_name = cleanup_vm("already-running-auto")
    run_cmd("create", "--name", vm_name)
    run_cmd("enable_autostart", "--name", vm_name)
    
    # Запускаємо машину вручну заздалегідь
    run_cmd("start", "--name", vm_name)
    time.sleep(1)

    # Виконуємо autostart_all
    result = run_cmd("autostart_all")

    # Вона НЕ повинна бути в списку тих, що "Autostarting...", бо вже працює
    assert f"Autostarting {vm_name}" not in result.stdout

