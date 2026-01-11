import pytest

def test_autostart_logic(run_cmd, cleanup_vm):
    """Перевірка команд enable/disable/list для автостарту"""
    vm_name = cleanup_vm("test-auto-vm")
    run_cmd("create", "--name", vm_name)

    # 1. Переконуємось, що спочатку списку немає або VM там відсутня
    initial_list = run_cmd("list_autostart")
    assert vm_name not in initial_list.stdout

    # 2. Вмикаємо автостарт
    enable_res = run_cmd("enable_autostart", "--name", vm_name)
    assert enable_res.returncode == 0
    assert "Autostart enabled" in enable_res.stdout

    # 3. Перевіряємо, що VM з'явилася у списку
    list_after_enable = run_cmd("list_autostart")
    assert vm_name in list_after_enable.stdout

    # 4. Перевіряємо також відображення в загальних конфігах (стовпчик AUTO)
    configs_res = run_cmd("list")
    # Шукаємо рядок з нашою VM і перевіряємо наявність "YES"
    vm_config_line = [line for line in configs_res.stdout.splitlines() if vm_name in line][0]
    assert "YES" in vm_config_line

    # 5. Вимикаємо автостарт
    disable_res = run_cmd("disable_autostart", "--name", vm_name)
    assert disable_res.returncode == 0
    assert "Autostart disabled" in disable_res.stdout

    # 6. Фінальна перевірка — список знову має бути порожнім (щодо цієї VM)
    final_list = run_cmd("list_autostart")
    assert vm_name not in final_list.stdout

