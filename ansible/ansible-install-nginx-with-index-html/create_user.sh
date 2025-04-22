#!/bin/bash

ansible-playbook -i inventory/hosts.yml playbooks/create_user.yml

