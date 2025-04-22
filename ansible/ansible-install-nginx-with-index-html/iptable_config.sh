#!/bin/bash

ansible-playbook -i inventory/hosts.yml playbooks/iptables_config.yml

