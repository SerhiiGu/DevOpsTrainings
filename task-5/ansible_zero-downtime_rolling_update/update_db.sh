#!/bin/bash

ansible-playbook -i inventory playbooks/update_service.yml -e "service_name=db" -e "image=mysql" -e "image_tag=8"

