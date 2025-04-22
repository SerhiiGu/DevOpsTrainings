#!/bin/bash

ansible-playbook -i inventory playbooks/update_service.yml -e "service_name=nginx" -e "image=nginx" -e "image_tag=alpine"

