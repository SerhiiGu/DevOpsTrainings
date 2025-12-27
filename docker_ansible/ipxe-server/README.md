

## RUN

docker compose run --rm ansible ansible-playbook -i inventory.ini playbooks/ipxe-server.yml

## How to use

Config ```/etc/dhcp/mac_filter.conf``` for a client,
restart the service ```systemctl restart isc-dhcp-server```
and you're ready to go.

**Pay attention to an other DHCP server in the network, it can intercept leases and iPXE may not work**


## - Додаткові ручні налаштування:

  Завантажити і змонтувати диск https://www.system-rescue.org/Download/

   ```bash
   mkdir /mnt/iso
   mount -o loop systemrescue-12.03-amd64.iso /mnt/iso
   ```

  Потім скопіювати його повністю на iPXE сервер:

```cp -r /mnt/iso/* /srv/httpboot/systemrescue/```

  і можна відмонтовувати.

