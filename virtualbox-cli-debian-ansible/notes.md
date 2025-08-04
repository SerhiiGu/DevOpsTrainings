```
vm-manager.sh create --name tst2 --iso debian-12.11.0-amd64-netinst.iso

vm-manager.sh destroy --name tst2

VBoxManage list hdds; VBoxManage list vms

VBoxManage closemedium disk 0bdc2976-5261-4c7b-9c5e-3876c8b01949 --delete



cp qqw.vdi ../tst2.vdi
cp /root/VirtualBox\ VMs/qqw/qqw.vbox ../tst2.vbox

VBoxManage showmediuminfo /opt/vms/qqw.vdi

vm-manager.sh import --name qqw --disk ../tst2.vdi --config ../tst2.vbox 


vm-manager.sh import --name d_190 --disk debian12_template_190.vdi --config debian12_template_190.vbox

VBoxManage showvminfo "$VM_NAME" --machinereadable | grep -i 



grep -oP '<StorageController[^>]+name="[^"]+"' "/root/VirtualBox VMs/perl5-193/perl5-193.vbox" \
    | grep SATA | head -n1 | sed -E 's/.*name="([^"]+)".*/\1/'
	
	
    local TARGET_CONFIG_PATH="${HOME}/VirtualBox VMs/${VM_NAME}/${VM_NAME}.vbox"
    CONTROLLER=$(get_sata_controller_name "$TARGET_CONFIG_PATH")
```
