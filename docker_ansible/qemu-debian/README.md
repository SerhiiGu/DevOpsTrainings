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



## Testing procedure(only for development)

1. Copy test package and run tests

   ```bash
   docker compose run --rm ansible ansible-playbook -i inventory.ini playbooks/tests_qemu.yml
   ```



