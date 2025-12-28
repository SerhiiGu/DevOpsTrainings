## Requirements

Debian 13

## Usage

  - Autoinstall: Debian 13
  - Memtest
  - Rescue purposes: SystemRescueCD


## RUN

   ```bash
   docker compose run --rm ansible ansible-playbook -i inventory.ini playbooks/ipxe-server.yml
   ```

## How to use

Config ```/etc/dhcp/mac_filter.conf``` for a client,
restart the service ```systemctl restart isc-dhcp-server```
and you're ready to go.

**Pay attention to an other DHCP server in the network, it can intercept leases and iPXE may not work**


## Manual additional step

Download iso [SystemRescueCD](https://www.system-rescue.org/Download/) and mount it

   ```bash
   mkdir /mnt/iso
   mount -o loop systemrescue-12.03-amd64.iso /mnt/iso
   ```

  Copy its entire data to iPXE server:

```cp -r /mnt/iso/* /srv/httpboot/systemrescue/```

  and you can umount and remove iso.

