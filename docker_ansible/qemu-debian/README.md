## Dependencies

Debian 13


## Install procedue

1. Build QEMU engine
   ```bash
   docker compose run --rm ansible ansible-playbook -i inventory.ini playbooks/install_qemu.yml
   ```

2. Install QEMU VM manager

   ```bash
   docker compose run --rm ansible ansible-playbook -i inventory.ini playbooks/qemu_manager.yml
   ```

