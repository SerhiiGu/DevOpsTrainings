- name: VM Manager tool for provisioning of VMs
  hosts: all
  become: yes

  roles:
    - vm_manager

