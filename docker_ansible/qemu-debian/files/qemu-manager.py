#!/usr/bin/env python3
import os
import sys
import json
import argparse
import subprocess
import asyncio
import socket
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

    async def send_qmp_command(self, name, cmd, args=None):
        client = QMPClient(name)
        try:
            await client.connect(self._get_socket_path(name))
            res = await client.execute(cmd, args)
            await client.disconnect()
            return res
        except Exception as e:
            return f"Error: {e}"


    def create(self, args):
        path = self._get_vm_path(args.name)
        if os.path.exists(path):
            print(f"Error: VM {args.name} already exists.")
            return

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
            "-display", "none",
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

        vnc_setting = vm.get('vnc', 'none')
        if vnc_setting != 'none':
            cmd.extend(['-vnc', f'0.0.0.0:{vnc_display}'])
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

    async def stop(self, args):
        if not self.is_running(args.name):
            print(f"VM {args.name} is not running.")
            return

        if args.mode == "poweroff":
            await self.send_qmp_command(args.name, "quit")
            print("VM stopped (PowerOff).")
        else:
            await self.send_qmp_command(args.name, "system_powerdown")
            print("Sent ACPI PowerDown signal.")


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

                # Отримуємо розмір файлу в ГБ (реальне займане місце)
                disk_size_gb = 0.0
                if disk_path and os.path.exists(disk_path):
                    disk_size_gb = os.path.getsize(disk_path) / (1024**3)

                status = "RUNNING" if self.is_running(name) else "STOPPED"
                vms.append({"name": name, "status": status, "size": disk_size_gb})

        print(f"{'VM NAME':<20} {'STATUS':<15} {'DISK USAGE':<10}")
        print("-" * 50)

        # Сортування: спочатку запущені, потім за алфавітом
        sorted_vms = sorted(vms, key=lambda x: (x['status'] != 'RUNNING', x['name']))

        for vm in sorted_vms:
            status_formatted = f"[{vm['status']}]"
            size_str = f"{vm['size']:.2f} GB"
            print(f"{vm['name']:<20} {status_formatted:<15} {size_str:>10}")


    def show_configs(self):
        if not os.path.exists(VMS_DIR) or not os.listdir(VMS_DIR):
            print("No VMs found.")
            return

        header = f"{'VM NAME':<15} {'CPU':<5} {'RAM':<8} {'NET':<10} {'VNC_PORT':<10} {'AUTO':<6} {'ISO'}"
        print(header)
        print("-" * len(header))

        for f in sorted(os.listdir(VMS_DIR)):
            if f.endswith(".json"):
                name = f[:-5]
                vm = self.load_vm(name)

                cpu = vm.get('cpu', 'N/A')
                ram = f"{vm.get('ram', 0)}M"
                net = vm.get('net', 'user')
                vnc_val = vm.get('vnc', 'none')
                vnc_display = f"{5900 + int(vnc_val)}" if vnc_val != 'none' else "off"
                auto = "YES" if vm.get('autostart') else "NO"
                # Беремо тільки назву файлу ISO, щоб не захаращувати таблицю шляхами
                iso = os.path.basename(vm.get('iso', 'None')) if vm.get('iso') else "None"

                print(f"{name:<15} {cpu:<5} {ram:<8} {net:<10} {vnc_display:<10} {auto:<6} {iso}")


    def modify(self, args):
        vm = self.load_vm(args.name)
        is_active = self.is_running(args.name)

        if args.new_name and is_active:
            print(f"Error: Cannot rename running VM '{args.name}'. Stop it first.")
            return

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


    def check_health(self):
        if not os.path.exists(VMS_DIR) or not os.listdir(VMS_DIR):
            print("No VMs to check.")
            return

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


async def main():
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

    # List
    subparsers.add_parser("list")
   
    # Show VMs config parameters
    subparsers.add_parser("configs")

    # Modify
    p = subparsers.add_parser("modify")
    p.add_argument("--name", required=True)
    p.add_argument("--new_name")
    p.add_argument("--cpu", type=int)
    p.add_argument("--ram", type=int)
    p.add_argument("--net")
    p.add_argument("--vnc", help="VNC port (e.g. 5901. Min.: 5901) or 'none' to disable")
    p.add_argument("--iso")

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
        await mgr.stop(args)
    elif args.command == "list":
        mgr.list_vms()
    elif args.command == "configs":
        mgr.show_configs()
    elif args.command == "modify":
        mgr.modify(args)
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
        for f in os.listdir(VMS_DIR):
            if f.endswith(".json"):
                vm_name = f[:-5]
                vm = mgr.load_vm(vm_name)
                if vm.get('autostart') and not mgr.is_running(vm_name):
                    print(f"Autostarting {vm_name}...")
                    # Створюємо об'єкт args для виклику start()
                    class MockArgs: pass
                    start_args = MockArgs()
                    start_args.name = vm_name
                    mgr.start(start_args)
    elif args.command == "check":
        mgr.check_health()
    else:
        parser.print_help()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass

