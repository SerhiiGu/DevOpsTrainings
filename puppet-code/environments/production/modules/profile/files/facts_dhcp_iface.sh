#!/bin/bash

# Виведе перший інтерфейс типу enp*
iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^enp' | head -n1)

if [ -n "$iface" ]; then
  echo "dhcp_iface=${iface}"
fi

