#!/usr/bin/env python3
import os
import sys
import json
import argparse
import subprocess
import socket
from types import SimpleNamespace
from qemu.qmp import QMPClient

# Налаштування шляхів
BASE_DIR = os.path.expanduser("~/.config/qemu-manager")
VMS_DIR = os.path.join(BASE_DIR, "vms")
DISK_DIR = os.path.join(BASE_DIR, "disks")
ISO_DIR = "/var/lib/libvirt/images" 

os.makedirs(VMS_DIR, exist_ok=True)
os.makedirs(DISK_DIR, exist_ok=True)

class VMManager:
    def __init__(self):
        self.qmp_timeout = 3

    def _get_vm_path(self, name):
        return os.path.join(VMS_DIR, f"{name}.json")

    def _get_disk_path(self, name):
        return os.path.join(DISK_DIR, f"{name}.qcow2")

    def _get_socket_path(self, name):
        return f"/tmp/qmp-{name}.sock"

    def is_running(self, name):
        sock_path = self._get_socket_path(name)
        if not os.path.exists(sock_path):
            return False
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(0.5)
                s.connect(sock_path)
                return True
        except (ConnectionRefusedError, socket.timeout):
            if os.path.exists(sock_path):
                os.remove(sock_path)
            return False

    def load_vm(self, name):
        path = self._get_vm_path(name)
        if not os.path.exists(path):
            print(f"Error: VM '{name}' not found.")
            sys.exit(1)
        with open(path, 'r') as f:
            return json.load(f)

    def save_vm(self, name, data):
        with open(self._get_vm_path(name), 'w') as f:
            json.dump(data, f, indent=4)


    def send_qmp_command(self, vm_name, command_name):
        sock_path = self._get_socket_path(vm_name)
        if not os.path.exists(sock_path):
            print(f"Error: QMP socket not found at {sock_path}")
            return

        try:
            # Створюємо звичайний Unix сокет
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            client.connect(sock_path)

            # 1. При підключенні QEMU надсилає вітання (greeting)
            initial_data = client.recv(1024)

            # 2. Треба активувати можливості QMP (qmp_capabilities)
            client.sendall(json.dumps({"execute": "qmp_capabilities"}).encode())
            client.recv(1024) # отримуємо {"return": {}}

            # 3. Надсилаємо реальну команду
            cmd = {"execute": command_name}
            client.sendall(json.dumps(cmd).encode())
            response = client.recv(1024)

            client.close()
            return json.loads(response)
        except Exception as e:
            print(f"QMP Error: {e}")
            return None


    def create(self, args):
        path = self._get_vm_path(args.name)
        if os.path.exists(path):
            print(f"Error: VM {args.name} already exists.")
            sys.exit(1)

        disk_path = self._get_disk_path(args.name)
        print(f"Creating disk {disk_path}...")
        subprocess.run(["qemu-img", "create", "-f", "qcow2", disk_path, f"{args.size}G"], check=True)

        vnc_display = "none"
        if args.vnc:
            try:
                port = int(args.vnc)
                # Якщо ввели 5901 або просто 1
                vnc_display = str(port - 5900) if port >= 5900 else str(port)
                print(f"VNC display set to {vnc_display} (Port {5900 + int(vnc_display)})")
            except ValueError:
                print("Warning: Invalid VNC port, disabling VNC.")

        vm_data = {
            "name": args.name,
            "cpu": args.cpu,
            "ram": args.ram,
            "disk": disk_path,
            "iso": args.iso,
            "boot_order": args.boot_order,
            "net": args.net,
            "vnc": vnc_display,
            "autostart": False
        }
        self.save_vm(args.name, vm_data)
        print(f"VM {args.name} created successfully.")


    def start(self, args):
        vm = self.load_vm(args.name)
        if self.is_running(args.name):
            print(f"VM {args.name} is already running.")
            return

        sock = self._get_socket_path(args.name)
        # Сучасний синтаксис для QEMU 10.x
        cmd = [
            "qemu-system-x86_64",
            "-name", vm['name'],
            "-m", str(vm['ram']),
            "-smp", str(vm['cpu']),
            "-drive", f"file={vm['disk']},format=qcow2,if=virtio",
            "-qmp", f"unix:{sock},server,nowait",
            "-daemonize"
        ]

        if vm['iso']:
            iso_path = os.path.join(ISO_DIR, vm['iso'])
            cmd.extend(["-cdrom", iso_path])
        
        if vm['net'] == "bridge" and not os.path.exists("/sys/class/net/br0"):
            print("Error: Bridge interface br0 not found on host!")
            return
        else:
            cmd.extend(["-netdev", "bridge,id=n1,br=br0", "-device", "virtio-net-pci,netdev=n1"])

        vnc_port = vm.get('vnc', 'none')
        if vnc_port != 'none':
            cmd.extend(['-vnc', f'0.0.0.0:{vnc_port}'])
        else:
            cmd.extend(['-display', 'none'])

        try:
            # Використовуємо capture_output щоб побачити помилку "not compiled into this binary"
            proc = subprocess.run(cmd, capture_output=True, text=True)
            if proc.returncode == 0:
                print(f"VM {args.name} started (headless).")
            else:
                print(f"CRITICAL ERROR starting QEMU:\n{proc.stderr}")
        except Exception as e:
            print(f"Failed to execute QEMU: {e}")


    def stop(self, args):
        if not self.is_running(args.name):
            print(f"VM {args.name} is not running.")
            sys.exit(1)

        if args.mode == "poweroff":
            self.send_qmp_command(args.name, "quit")
            print("VM stopped (PowerOff).")
        else:
            self.send_qmp_command(args.name, "system_powerdown")
            print("Sent ACPI PowerDown signal.")


    def delete_vm(self, name):
        # 1. Перевірка наявності VM
        path = self._get_vm_path(name)
        if not os.path.exists(path):
            print(f"Error: VM '{name}' not found.")
            sys.exit(1)

        vm = self.load_vm(name)
        disk_path = vm.get('disk')

        # 2. Якщо VM працює — гасимо її через poweroff
        if self.is_running(name):
            print(f"VM '{name}' is running. Sending poweroff signal...")
            try:
                class StopArgs:
                    def __init__(self, name, mode):
                        self.name = name
                        self.mode = mode
                
                # Викликаємо стоп у режимі poweroff
                self.stop(StopArgs(name, 'poweroff'))

                # Чекаємо до 10 секунд, поки процес реально зникне
                import time
                for _ in range(10):
                    if not self.is_running(name):
                        break
                    time.sleep(1)
            except Exception as e:
                print(f"Warning: Issue while stopping VM: {e}")

        # 3. Остаточна перевірка перед видаленням файлів
        if self.is_running(name):
            print(f"Error: Could not stop VM '{name}'. Deletion aborted to prevent disk corruption.")
            sys.exit(1)

        # 4. Видалення файлів
        try:
            # Видаляємо JSON конфіг
            os.remove(path)

            # Видаляємо диск
            if disk_path and os.path.exists(disk_path):
                os.remove(disk_path)
                print(f"Disk {os.path.basename(disk_path)} deleted.")

            # Чистимо монітор-сокет
            sock_path = self._get_socket_path(name)
            if os.path.exists(sock_path):
                os.remove(sock_path)

            print(f"VM '{name}' and all its data have been removed.")

        except Exception as e:
            print(f"Error during file removal: {e}")


    def list_vms(self):
        vms = []
        if not os.path.exists(VMS_DIR) or not os.listdir(VMS_DIR):
            print("No VMs found.")
            return

        for f in os.listdir(VMS_DIR):
            if f.endswith(".json"):
                name = f[:-5]
                vm_data = self.load_vm(name)
                disk_path = vm_data.get('disk')

                # 1. Розмір диска (реальне займане місце)
                disk_size_gb = 0.0
                if disk_path and os.path.exists(disk_path):
                    disk_size_gb = os.path.getsize(disk_path) / (1024**3)

                # 2. Статус та ресурси (CPU/RAM)
                status = "STOPPED"
                cpu_load = "-"
                ram_rss = "-"

                try:
                    pid = subprocess.check_output(["pgrep", "-f", f"qemu-system-x86_64.*-name {name}"], text=True).strip().split('\n')[0]
                    status = "RUNNING"
                    ps_out = subprocess.check_output(["ps", "-p", pid, "-o", "%cpu,rss"], text=True).split('\n')[1].split()

                    cpu_load = f"{ps_out[0]}%"
                    ram_rss = f"{float(ps_out[1])/1024:.0f}M"
                except (subprocess.CalledProcessError, IndexError):
                    pass

                # 3. Конфігураційні дані
                vnc_val = vm_data.get('vnc', 'none')
                vnc_port = f"{5900 + int(vnc_val)}" if vnc_val != 'none' else "off"
                iso = os.path.basename(vm_data.get('iso', 'None')) if vm_data.get('iso') else "None"

                vms.append({
                    "name": name,
                    "status": status,
                    "disk": f"{disk_size_gb:.2f}G",
                    "cpu_conf": vm_data.get('cpu', '1'),
                    "cpu_load": cpu_load,
                    "ram_max": f"{vm_data.get('ram', 0)}M",
                    "ram_rss": ram_rss,
                    "net": vm_data.get('net', 'user'),
                    "vnc": vnc_port,
                    "auto": "YES" if vm_data.get('autostart') else "NO",
                    "iso": iso
                })

        # 4. Вивід об'єднаної таблиці
        # Використовуємо трохи ширші колонки для читабельності
        header = (f"{'VM NAME':<15} {'STATUS':<10} {'DISK':<7} {'CPU':<5} {'LOAD':<7} "
                  f"{'RAM':<7} {'RSS':<7} {'VNC':<6} {'AUTO':<5} {'ISO'}")
        print(header)
        #print("-" * 90)
        print("-" * len(header))

        # Сортування: RUNNING спочатку, далі за алфавітом
        sorted_vms = sorted(vms, key=lambda x: (x['status'] != 'RUNNING', x['name']))

        for v in sorted_vms:
            st = f"[{v['status']}]"
            print(f"{v['name']:<15} {st:<10} {v['disk']:<7} {v['cpu_conf']:<5} {v['cpu_load']:<7} "
                  f"{v['ram_max']:<7} {v['ram_rss']:<7} {v['vnc']:<6} {v['auto']:<5} {v['iso']}")


    def modify(self, args):
        vm = self.load_vm(args.name)
        is_active = self.is_running(args.name)

        if args.new_name and is_active:
            print(f"Error: Cannot rename running VM '{args.name}'. Stop it first.")
            sys.exit(1)

        if args.cpu: vm['cpu'] = args.cpu
        if args.ram: vm['ram'] = args.ram
        if args.iso: vm['iso'] = args.iso
        if args.net: vm['net'] = args.net

        if args.vnc:
            if args.vnc.lower() == 'none':
                vm['vnc'] = 'none'
            else:
                try:
                    port = int(args.vnc)
                    if port >= 5900:
                        vm['vnc'] = str(port - 5900)
                    else:
                        vm['vnc'] = str(port) # якщо користувач ввів просто "1"
                    print(f"VNC port set to {5900 + int(vm['vnc'])}")
                except ValueError:
                    print("Error: VNC port must be a number or 'none'")

        #Full rename logic (name + disk + config)
        if args.new_name:
            old_name = args.name
            new_name = args.new_name

            old_disk_path = vm['disk']
            # Створюємо новий шлях до диска, зберігаючи директорію та розширення
            disk_dir = os.path.dirname(old_disk_path)
            new_disk_path = os.path.join(disk_dir, f"{new_name}.qcow2")

            try:
                # Перейменовуємо файл диска в системі
                if os.path.exists(old_disk_path):
                    os.rename(old_disk_path, new_disk_path)
                    print(f"Disk renamed: {os.path.basename(old_disk_path)} -> {os.path.basename(new_disk_path)}")

                # Оновлюємо дані в об'єкті
                vm['name'] = new_name
                vm['disk'] = new_disk_path

                # Зберігаємо новий конфіг і видаляємо старий
                self.save_vm(new_name, vm)
                os.remove(self._get_vm_path(old_name))
                print(f"VM '{old_name}' successfully renamed to '{new_name}'.")

            except Exception as e:
                print(f"Error during renaming: {e}")
                # Тут можна додати логіку відкату, якщо rename файлу не вдався
        else:
            # Звичайна модифікація параметрів без зміни імені
            self.save_vm(args.name, vm)
            print(f"VM '{args.name}' updated parameters.")


    def clone_vm(self, old_name, new_name):
        old_path = self._get_vm_path(old_name)
        new_path = self._get_vm_path(new_name)

        if not os.path.exists(old_path):
            print(f"Error: Source VM '{old_name}' not found.")
            sys.exit(1)
        if os.path.exists(new_path):
            print(f"Error: Destination VM '{new_name}' already exists.")
            sys.exit(1)
        if self.is_running(old_name):
            print(f"Error: Cannot clone a running VM. Please stop '{old_name}' first.")
            sys.exit(1)

        try:
            # 1. Завантажуємо старий конфіг
            vm = self.load_vm(old_name)

            # 2. Копіюємо файл диска
            old_disk = vm['disk']
            new_disk = os.path.join(DISK_DIR, f"{new_name}.qcow2")

            print(f"Cloning disk {os.path.basename(old_disk)} -> {os.path.basename(new_disk)}...")
            # Використовуємо cp --sparse=always через subprocess для швидкості
            subprocess.run(["cp", "--sparse=always", old_disk, new_disk], check=True)

            # 3. Оновлюємо дані для нової VM
            vm['name'] = new_name
            vm['disk'] = new_disk
            vm['autostart'] = False

            # Disable VNC, щоб уникнути конфліктів портів
            vm['vnc'] = 'none'

            # 4. Зберігаємо новий конфіг
            self.save_vm(new_name, vm)
            print(f"VM '{old_name}' successfully cloned to '{new_name}'.")

        except Exception as e:
            print(f"Error during cloning: {e}")


    def check_health(self):
        if not os.path.exists(VMS_DIR) or not os.listdir(VMS_DIR):
            print("No VMs to check.")
            sys.exit(1)

        print(f"{'VM NAME':<20} {'DISK':<10} {'ISO':<10} {'NET':<10}")
        print("-" * 55)

        for f in os.listdir(VMS_DIR):
            if f.endswith(".json"):
                name = f[:-5]
                vm = self.load_vm(name)
                disk_ok = "OK" if os.path.exists(vm['disk']) else "MISSING"
                iso_ok = "N/A"
                if vm.get('iso'):
                    iso_path = os.path.join(ISO_DIR, vm['iso'])
                    iso_ok = "OK" if os.path.exists(iso_path) else "MISSING"
                net_ok = "OK"
                if vm.get('net') == "bridge" and not os.path.exists("/sys/class/net/br0"):
                    net_ok = "NO_BRIDGE"

                print(f"{name:<20} {disk_ok:<10} {iso_ok:<10} {net_ok:<10}")


def main():
    mgr = VMManager()
    parser = argparse.ArgumentParser(description="QEMU VM Manager")
    subparsers = parser.add_subparsers(dest="command")

    # Create
    p = subparsers.add_parser("create")
    p.add_argument("--name", required=True)
    p.add_argument("--size", default=20, type=int)
    p.add_argument("--iso", default="")
    p.add_argument("--cpu", default=2, type=int)
    p.add_argument("--ram", default=1024, type=int)
    p.add_argument("--boot_order", default="dvd,disk,net")
    p.add_argument("--net", default="user")
    p.add_argument("--vnc", help="VNC port (e.g. 5901. Min.: 5901) or 'none'", default="none")

    # Start
    p = subparsers.add_parser("start")
    p.add_argument("--name", required=True)

    # Stop
    p = subparsers.add_parser("stop")
    p.add_argument("--name", required=True)
    p.add_argument("--mode", choices=["acpi", "poweroff"], default="acpi")

    # Delete
    p = subparsers.add_parser("delete", help="Delete a VM and its disk")
    p.add_argument("--name", required=True, help="Name of the VM to delete")
    p.add_argument("--force", "-f", action="store_true", help="Skip confirmation prompt")

    # List
    subparsers.add_parser("list")
   
    # Modify
    p = subparsers.add_parser("modify")
    p.add_argument("--name", required=True)
    p.add_argument("--new_name")
    p.add_argument("--cpu", type=int)
    p.add_argument("--ram", type=int)
    p.add_argument("--net")
    p.add_argument("--vnc", help="VNC port (e.g. 5901. Min.: 5901) or 'none' to disable")
    p.add_argument("--iso")

    # Clone
    p = subparsers.add_parser("clone", help="Clone an existing VM")
    p.add_argument("--name", required=True, help="Source VM name")
    p.add_argument("--new_name", required=True, help="New VM name")

    # Autostart
    subparsers.add_parser("list_autostart")
    p = subparsers.add_parser("enable_autostart")
    p.add_argument("--name", required=True)
    p = subparsers.add_parser("disable_autostart")
    p.add_argument("--name", required=True)

    # Autostart All
    subparsers.add_parser("autostart_all")

    # Check for correct recource bindings
    subparsers.add_parser("check")

    args = parser.parse_args()

    if args.command == "create":
        mgr.create(args)
    elif args.command == "start":
        mgr.start(args)
    elif args.command == "stop":
        mgr.stop(args)
    elif args.command == "delete":
        # Перевіряємо чи існує VM перед запитом підтвердження
        path = os.path.join(VMS_DIR, f"{args.name}.json")
        if not os.path.exists(path):
            print(f"Error: VM '{args.name}' does not exist.")
            sys.exit(1)
        else:
            # Якщо force активовано, підтвердження не запитуємо
            if args.force:
                mgr.delete_vm(args.name)
            else:
                confirm = input(f"Are you sure you want to DELETE VM '{args.name}' and its disk? (y/N): ")
                if confirm.lower() == 'y':
                    mgr.delete_vm(args.name)
                else:
                    print("Operation cancelled.")
    elif args.command == "list":
        mgr.list_vms()
    elif args.command == "modify":
        mgr.modify(args)
    elif args.command == "clone":
        mgr.clone_vm(args.name, args.new_name)
    elif args.command == "enable_autostart":
        v = mgr.load_vm(args.name); v['autostart'] = True; mgr.save_vm(args.name, v)
        print("Autostart enabled.")
    elif args.command == "disable_autostart":
        v = mgr.load_vm(args.name); v['autostart'] = False; mgr.save_vm(args.name, v)
        print("Autostart disabled.")
    elif args.command == "list_autostart":
        for f in os.listdir(VMS_DIR):
            v = mgr.load_vm(f[:-5])
            if v.get('autostart'): print(v['name'])
    elif args.command == "autostart_all":
        if not os.path.exists(VMS_DIR):
            return
        for filename in os.listdir(VMS_DIR):
            if filename.endswith(".json"):
                vm_name = filename[:-5]  # Прибираємо .json
                try:
                    vm = mgr.load_vm(vm_name)
                    # Перевіряємо прапорець автостарту та чи не запущена вона вже
                    if vm.get('autostart') and not mgr.is_running(vm_name):
                        print(f"Autostarting {vm_name}...")
                        # Використовуємо SimpleNamespace замість MockArgs
                        # Це імітує об'єкт, який повертає argparse
                        mgr.start(SimpleNamespace(name=vm_name))
                except Exception as e:
                    print(f"Error autostarting {vm_name}: {e}")
    elif args.command == "check":
        mgr.check_health()
    else:
        parser.print_help()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)

