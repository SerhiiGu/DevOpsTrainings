#!/bin/bash

ansible-playbook -i inventory/hosts.yml playbooks/install_nginx.yml

