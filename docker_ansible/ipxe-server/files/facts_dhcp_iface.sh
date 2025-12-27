#!/bin/bash

# Виведе перший інтерфейс типу enp*
iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^enp' | head -n1)

echo -n "${iface}" | tr -d '[:space:]'

