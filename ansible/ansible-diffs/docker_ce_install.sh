#!/bin/bash

ansible-playbook -i inventory/hosts.yml playbooks/docker_ce_install.yml

