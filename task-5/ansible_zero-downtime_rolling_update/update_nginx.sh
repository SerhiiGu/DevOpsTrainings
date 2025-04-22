#!/bin/bash

ansible-playbook -i inventory playbooks/update_service.yml -e "service_name=nginx"

