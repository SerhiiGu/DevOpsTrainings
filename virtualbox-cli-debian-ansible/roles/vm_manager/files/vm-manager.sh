#!/usr/bin/env bash

#--------------------------------------------
# VM Manager Script for VirtualBox CLI
#--------------------------------------------
# Usage:
#   vm-manager.sh FUNCTION [--params ...]
#
# Functions:
#   create          Create a new VM
#   modify          Modify existing VM configuration
#   start           Start a VM (headless)
#   stop            Stop a VM (ACPI or PowerOff)
#   list            List all VMs (sorted by running first)
#   list_autostart  List VMs with autostart enabled
#   enable_autostart Enable VM autostart
#   disable_autostart Disable VM autostart
#   help            Show this help
#
#--------------------------------------------

# Default paths
ISO_DIR="/opt/iso"
VM_DIR="/opt/vms"

# Ensure required dirs exist
[ ! -d "$ISO_DIR" ] && mkdir -p "$ISO_DIR"
[ ! -d "$VM_DIR" ] && mkdir -p "$VM_DIR"

#--------------------------------------------
# Utility functions
#--------------------------------------------

error_exit() {
    echo "ERROR: $1" >&2
    exit 1
}

check_vm_exists() {
    local vm="$1"
    if ! VBoxManage showvminfo "$vm" >/dev/null 2>&1; then
        error_exit "VM '$vm' does not exist."
    fi
}

check_vm_not_exists() {
    local vm="$1"
    if VBoxManage showvminfo "$vm" >/dev/null 2>&1; then
        error_exit "VM '$vm' already exists."
    fi
}

check_vm_powered_off() {
    local vm="$1"
    local state
    state=$(VBoxManage showvminfo "$vm" --machinereadable | grep -E '^VMState=' | cut -d'"' -f2)
    if [[ "$state" != "poweroff" ]]; then
        error_exit "VM '$vm' is not powered off. Please stop it before modifying."
    fi
}

get_sata_controller_name() {
    local config_path="$1"
    local controller
    controller=$(grep -oP '<StorageController[^>]+name="[^"]+"' "$config_path" \
        | grep SATA | head -n1 | sed -E 's/.*name="([^"]+)".*/\1/')
    echo "$controller"
}

#--------------------------------------------
# Function: create
#--------------------------------------------
create_vm() {
    # Defaults
    NAME=""
    DISK_SIZE_GB="20"
    CD_NAME=""
    BOOT_ORDER="dvd,disk"
    CPU_NUM="2"
    RAM_MB="1024"
    NET_TYPE="bridged"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) NAME="$2"; shift 2 ;;
            --size) DISK_SIZE_GB="$2"; shift 2 ;;
            --iso) CD_NAME="$2"; shift 2 ;;
            --boot_order) BOOT_ORDER="$2"; shift 2 ;;
            --cpu) CPU_NUM="$2"; shift 2 ;;
            --ram) RAM_MB="$2"; shift 2 ;;
            --net) NET_TYPE="$2"; shift 2 ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$NAME" ]] && error_exit "Please provide --name VM_NAME."
    if VBoxManage showvminfo "$NAME" >/dev/null 2>&1; then
        error_exit "VM '$NAME' already exist."
    fi

    DISK_PATH="$VM_DIR/$NAME.vdi"

    # Check disk does not already exist
    if [[ -f "$DISK_PATH" ]]; then
        error_exit "Disk $DISK_PATH already exists."
    fi

    # Create disk
    echo "Creating disk $DISK_PATH with size ${DISK_SIZE_GB}G..."
    VBoxManage createmedium disk --filename "$DISK_PATH" --size "$((DISK_SIZE_GB * 1024))" --format VDI --variant Standard || error_exit "Failed to create disk."

    # Create VM
    echo "Creating VM $NAME..."
    VBoxManage createvm --name "$NAME" --register || error_exit "Failed to create VM."

    # Set memory and CPUs
    VBoxManage modifyvm "$NAME" --memory "$RAM_MB" --cpus "$CPU_NUM" --cpuexecutioncap 100 || error_exit "Failed to set resources."

    # Set network
    if [[ "$NET_TYPE" == "bridged" ]]; then
        IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -Ev 'lo|vboxnet|virbr' | head -n1)
        [[ -z "$IFACE" ]] && error_exit "No suitable bridged interface found."
        VBoxManage modifyvm "$NAME" --nic1 bridged --bridgeadapter1 "$IFACE" || error_exit "Failed to modify network."
    else
        VBoxManage modifyvm "$NAME" --nic1 "$NET_TYPE" || error_exit "Failed to modify network."
    fi

    # Storage controller
    VBoxManage storagectl "$NAME" --name "SATA Controller" --add sata --controller IntelAHCI --portcount 1 --hostiocache on || error_exit "Failed to add SATA controller."

    # Attach disk as SSD
    VBoxManage storageattach "$NAME" \
        --storagectl "SATA Controller" \
        --port 0 --device 0 \
        --type hdd --nonrotational on \
	--medium "$DISK_PATH" || error_exit "Failed to attach disk."

    # Create IDE controller for CD/DVD
    VBoxManage storagectl "$NAME" --name "IDE Controller" --add ide || error_exit "Failed to add IDE controller."

    if [[ -n "$CD_NAME" ]]; then
        ISO_PATH="$ISO_DIR/$CD_NAME"
        if [[ ! -f "$ISO_PATH" ]]; then
            error_exit "ISO file $ISO_PATH does not exist."
        fi
        VBoxManage storageattach "$NAME" \
            --storagectl "IDE Controller" \
            --port 0 --device 0 \
            --type dvddrive --medium "$ISO_PATH" || error_exit "Failed to attach ISO."
    else
        # Empty drive
        VBoxManage storageattach "$NAME" \
            --storagectl "IDE Controller" \
            --port 0 --device 0 \
            --type dvddrive --medium emptydrive
    fi

    # Boot order
    IFS=',' read -ra BOOT <<< "$BOOT_ORDER"
    for idx in "${!BOOT[@]}"; do
        VBoxManage modifyvm "$NAME" --boot$((idx+1)) "${BOOT[$idx]}"
    done

    echo "VM '$NAME' created successfully."
}

#--------------------------------------------
# Function: modify
#--------------------------------------------
modify_vm() {
    local VM_NAME=""
    local ARGS=()

    # Extract VM name first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            *) ARGS+=("$1"); shift ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please specify --name VM_NAME."

    check_vm_exists "$VM_NAME"
    check_vm_powered_off "$VM_NAME"

    for (( i=0; i<${#ARGS[@]}; i++ )); do
        case "${ARGS[i]}" in
            --new_name)
                NEW_VM_NAME="${ARGS[i+1]}"
                [[ -z "$NEW_VM_NAME" ]] && error_exit "--new_name requires a value."

                # Get SATA Controller name
                local TARGET_CONFIG_PATH="${HOME}/VirtualBox VMs/${VM_NAME}/${VM_NAME}.vbox"
                CONTROLLER=$(get_sata_controller_name "$TARGET_CONFIG_PATH")
                # Find attached SATA disk UUID
                DISK_LINE=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep "$CONTROLLER" | grep 'UUID')

                if [[ -z "$DISK_LINE" ]]; then
                    error_exit "No disk found attached to SATA Controller port 0 device 0."
                fi

                # Extract UUID
		UUID=$(echo "$DISK_LINE" | grep "UUID" | cut -d'=' -f2 | tr -d '"')

                if [[ -z "$UUID" ]]; then
                    error_exit "Unable to extract disk UUID."
                fi

                # Find actual disk file path
                VDI_PATH=$(VBoxManage showmediuminfo disk "$UUID" | \
                           awk -F ': ' '/Location:/ {print $2}' | xargs)
                [[ ! -f "$VDI_PATH" ]] && error_exit "Disk file not found at $VDI_PATH."

                # Detach disk for rename
                VBoxManage storageattach "$VM_NAME" \
                         --storagectl "$CONTROLLER" --port 0 --device 0 --medium none

                # Unregister the old disk
                VBoxManage closemedium disk "$UUID" || error_exit "Failed to close medium."

                # Rename disk file
                VDI_DIR=$(dirname "$VDI_PATH")
                VDI_EXT="${VDI_PATH##*.}"
                NEW_VDI_PATH="$VDI_DIR/${NEW_VM_NAME}.${VDI_EXT}"
                mv "$VDI_PATH" "$NEW_VDI_PATH" || error_exit "Failed to rename disk file."

		# Reattach disk to VM(automatic register)
                VBoxManage storageattach "$VM_NAME" --storagectl "$CONTROLLER" \
                    --port 0 --device 0 --type hdd --medium "$NEW_VDI_PATH" \
                    --nonrotational on || error_exit "Failed to reattach renamed disk."

                echo "Disk renamed and reattached: $NEW_VDI_PATH"

                # Rename VM
                VBoxManage modifyvm "$VM_NAME" --name "$NEW_VM_NAME" || error_exit "Failed to rename VM."
                echo "VM renamed from '$VM_NAME' to '$NEW_VM_NAME'."

                # Update VM_NAME for subsequent modifications
                VM_NAME="$NEW_VM_NAME"
                ((i++))
                ;;
            --cpu)
                VBoxManage modifyvm "$VM_NAME" --cpus "${ARGS[i+1]}" || error_exit "Failed to modify CPUs."
                ((i++))
                ;;
            --ram)
                VBoxManage modifyvm "$VM_NAME" --memory "${ARGS[i+1]}" || error_exit "Failed to modify RAM."
                ((i++))
                ;;
            --net)
                NET_TYPE="${ARGS[i+1]}"

                if [[ "$NET_TYPE" == "bridged" ]]; then
                   IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -Ev 'lo|vboxnet|virbr' | head -n1)
                   [[ -z "$IFACE" ]] && error_exit "No suitable bridged interface found."
                   VBoxManage modifyvm "$VM_NAME" --nic1 bridged --bridgeadapter1 "$IFACE" || error_exit "Failed to modify network."
                else
                   VBoxManage modifyvm "$VM_NAME" --nic1 "$NET_TYPE" || error_exit "Failed to modify network."
                fi
                ((i++))
                ;;
            --iso)
                ISO_ARG="${ARGS[i+1]}"
                if [[ "$ISO_ARG" == "" ]]; then
                    # Unmount ISO
                    VBoxManage storageattach "$VM_NAME" \
                        --storagectl "IDE Controller" \
                        --port 0 --device 0 \
                        --type dvddrive --medium none \
                        || error_exit "Failed to detach ISO."
                    echo "ISO detached from VM '$VM_NAME'."
                else
                    ISO_PATH="$ISO_DIR/${ISO_ARG}"
                    [[ ! -f "$ISO_PATH" ]] && error_exit "ISO $ISO_PATH not found."
                    VBoxManage storageattach "$VM_NAME" \
                        --storagectl "IDE Controller" \
                        --port 0 --device 0 \
                        --type dvddrive --medium "$ISO_PATH" \
                        || error_exit "Failed to attach ISO."
                    echo "ISO attached to VM '$VM_NAME': $ISO_PATH"
                fi
                ((i++))
                ;;
            --boot_order)
                IFS=',' read -ra BOOT <<< "${ARGS[i+1]}"
                for idx in "${!BOOT[@]}"; do
                    VBoxManage modifyvm "$VM_NAME" --boot$((idx+1)) "${BOOT[$idx]}"
                done
                ((i++))
                ;;
            *)
                error_exit "Unknown modify parameter: ${ARGS[i]}"
                ;;
        esac
    done

    echo "VM '$VM_NAME' modified successfully."
}

#--------------------------------------------
# Function: destroy
#--------------------------------------------
destroy_vm() {
    local VM_NAME=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."

    check_vm_exists "$VM_NAME"

    # Confirm deletion
    echo -n "Are you sure you want to destroy VM '$VM_NAME'? (yes/no): "
    read -r CONFIRM
    case "$CONFIRM" in
        [Yy][Ee][Ss]) ;;
        [Nn][Oo]) echo "Operation cancelled."; exit 0 ;;
        *) error_exit "Invalid response. Only 'yes' or 'no' allowed." ;;
    esac

    # Confirm disk deletion
    echo -n "Delete associated disk file(s) too? (yes/no): "
    read -r DEL_DISK
    case "$DEL_DISK" in
        [Yy][Ee][Ss]) DELETE_DISK="yes" ;;
        [Nn][Oo]) DELETE_DISK="no" ;;
        *) error_exit "Invalid response. Only 'yes' or 'no' allowed." ;;
    esac

    # Power off VM if running
    VMSTATE=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep '^VMState=' | cut -d'"' -f2)
    if [[ "$VMSTATE" != "poweroff" ]]; then
        echo "VM '$VM_NAME' is running. Stopping it..."
        VBoxManage controlvm "$VM_NAME" poweroff || error_exit "Failed to power off VM."
    fi

    if [[ "$DELETE_DISK" == "yes" ]]; then
        echo "Searching for attached disks..."

        # Find SATA disk and detach it
        local TARGET_CONFIG_PATH="${HOME}/VirtualBox VMs/${VM_NAME}/${VM_NAME}.vbox"
        CONTROLLER=$(get_sata_controller_name "$TARGET_CONFIG_PATH")
        DISK=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep "$CONTROLLER" | grep 'UUID')
        if [[ -n "$DISK" ]]; then
                UUID=$(echo "$DISK" | grep "UUID" | cut -d'=' -f2 | tr -d '"')
                if [[ -n "$UUID" && "$UUID" != "none" ]]; then
                    echo "Detaching disk on port 0 (UUID: $UUID)..."
                    VBoxManage storageattach "$VM_NAME" \
                        --storagectl "$CONTROLLER" \
                        --port 0 --device 0 \
                        --medium none || error_exit "Failed to detach disk on port $PORT"

                    echo "Deleting disk UUID $UUID and disk FILE $DISK_IMG..."
                    VBoxManage closemedium disk "$UUID" --delete || error_exit "Failed to delete disk $UUID"
                    rm -f $VM_DIR/$VM_NAME.vdi
                fi
        else
            echo "No SATA disks attached to VM."
        fi
    else
        echo "Disks will NOT be deleted. Only unregistering VM."
    fi

    # Unregister VM
    VBoxManage unregistervm "$VM_NAME" || error_exit "Failed to unregister VM."

    # Clean up VM folder
    VM_DIR="${HOME}/VirtualBox VMs/${VM_NAME}"
    if [[ -d "$VM_DIR" ]]; then
        echo "Removing VM directory: $VM_DIR"
        rm -rf "$VM_DIR" || error_exit "Failed to remove VM directory $VM_DIR."
    else
        echo "VM directory $VM_DIR does not exist."
    fi

    echo "VM '$VM_NAME' destroyed successfully."
}

#--------------------------------------------
# Function: config
#--------------------------------------------
config_vm() {
    local VM_NAME=""
    local ALL="no"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            --all) ALL="yes"; shift ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."

    check_vm_exists "$VM_NAME"

    if [[ "$ALL" == "yes" ]]; then
        VBoxManage showvminfo "$VM_NAME" --machinereadable
    else
        # Extract only key info
        local info=$(VBoxManage showvminfo "$VM_NAME" --machinereadable)

        echo "VM Name: $VM_NAME"
        echo "UUID: $(echo "$info" | grep '^UUID=' | cut -d'"' -f2)"
        echo "State: $(echo "$info" | grep '^VMState=' | cut -d'"' -f2)"
        echo "RAM: $(echo "$info" | grep '^memory=' | cut -d'=' -f2) MB"
        echo "CPUs: $(echo "$info" | grep '^cpus=' | cut -d'=' -f2)"
        
        echo "Boot Order:"
        for i in {1..4}; do
            dev=$(echo "$info" | grep "^boot$i=" | cut -d'"' -f2)
            [[ -n "$dev" && "$dev" != "none" ]] && echo "  boot$i → $dev"
        done

        echo "VRDE: $(echo "$info" | grep '^VRDE=' | cut -d'=' -f2 | tr -d '"')"
        echo "VRDE Port: $(echo "$info" | grep '^VRDEPort=' | cut -d'=' -f2 | tr -d '"')"

        echo "Disks:"
        VBoxManage showvminfo "$VM_NAME" | grep -A 10 "SATA Controller" | grep -E "Medium|Image"

        echo "CD/DVD drives:"
        VBoxManage showvminfo "$VM_NAME" | grep -A 10 "IDE Controller" | grep -E "Medium|Image"

        echo "Network:"
        echo "$info" | grep -E '^nic1=' | awk -F'=' '{print "Adapter 1: " $2}'
    fi
}

#--------------------------------------------
# Function: clone
#--------------------------------------------
clone_vm() {
    local VM_NAME=""
    local NEW_VM_NAME=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            --new_name) NEW_VM_NAME="$2"; shift 2 ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."
    [[ -z "$NEW_VM_NAME" ]] && error_exit "Please provide --new_name NEW_VM_NAME."
    check_vm_exists "$VM_NAME"
    check_vm_not_exists "$NEW_VM_NAME"

    echo "Cloning VM '$VM_NAME' to '$NEW_VM_NAME'..."

    # Clone VM
    VBoxManage clonevm "$VM_NAME" --name "$NEW_VM_NAME" \
        --register || error_exit "Failed to clone VM."

    local TARGET_CONFIG_PATH="${HOME}/VirtualBox VMs/${VM_NAME}/${VM_NAME}.vbox"
    CONTROLLER=$(get_sata_controller_name "$TARGET_CONFIG_PATH")

    # Find the cloned VM's disk
    local CLONED_DISK
    CLONED_DISK=$(VBoxManage showvminfo "$NEW_VM_NAME" --machinereadable | grep "${CONTROLLER}-0-0" | awk -F'"' '{print $4}')
    [[ -z "$CLONED_DISK" ]] && error_exit "Cannot find cloned VM disk."

    echo "Found cloned disk: $CLONED_DISK"

    # Prepare target path
    local DISK_FILENAME
    DISK_FILENAME=$(basename "$CLONED_DISK")
    local NEW_DISK_PATH="$VM_DIR/$DISK_FILENAME"

    # Detach disk from VM
    VBoxManage storageattach "$NEW_VM_NAME" --storagectl "${CONTROLLER}" \
        --port 0 --device 0 --medium none || error_exit "Failed to detach disk."

    # Close medium in VirtualBox registry
    VBoxManage closemedium disk "$CLONED_DISK" || error_exit "Failed to close medium."

    # Move disk
    echo "Moving disk to: $NEW_DISK_PATH"
    mv "$CLONED_DISK" "$NEW_DISK_PATH" || error_exit "Failed to move disk."

    # Update storage controller to point to new disk
    VBoxManage storageattach "$NEW_VM_NAME" \
        --storagectl "$CONTROLLER" \
        --port 0 --device 0 --type hdd --nonrotational on \
        --medium "$NEW_DISK_PATH" || error_exit "Failed to update disk attachment."

    echo "VM '$NEW_VM_NAME' successfully cloned and disk moved to $NEW_DISK_PATH."
}

#--------------------------------------------
# Function: console
#--------------------------------------------
console_vm() {
    local VM_NAME=""
    local VRDE_PORT=""
    local OFF_MODE="0"
    local MIN_PORT=5000
    local MAX_PORT=5500
    local VM_CONF_DIR="${HOME}/VirtualBox VMs/*/*.vbox"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            --off) OFF_MODE="1"; shift ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."
    check_vm_exists "$VM_NAME"

    # Check VM state
    local VMSTATE
    VMSTATE=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep -E '^VMState=' | cut -d'"' -f2)

    if [[ "$OFF_MODE" == "1" ]]; then
        echo "Disabling VRDE on VM $VM_NAME..."

        if [[ "$VMSTATE" == "poweroff" ]]; then
            VBoxManage modifyvm "$VM_NAME" --vrde off || error_exit "Failed to disable VRDE."
            VBoxManage modifyvm "$VM_NAME" --vrdeport 0 || error_exit "Failed to reset VRDE port."
        else
            VBoxManage controlvm "$VM_NAME" vrde off || error_exit "Failed to disable VRDE while VM is running."
            VBoxManage controlvm "$VM_NAME" vrdeport 0 || error_exit "Failed to reset VRDE port while VM is running."
        fi

        echo "VRDE disabled for VM '$VM_NAME'."
        return 0
    fi

    # Check if VRDE is enabled
    local VRDE_STATE
    VRDE_STATE=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep -i '^VRDE=' | cut -d'=' -f2 | tr -d '"')

    if [[ "$VRDE_STATE" != "on" ]]; then
        echo "Enabling VRDE on VM $VM_NAME..."
        if [[ "$VMSTATE" == "poweroff" ]]; then
            VBoxManage modifyvm "$VM_NAME" --vrde on || error_exit "Failed to enable VRDE."
        else
            VBoxManage controlvm "$VM_NAME" vrde on || error_exit "Failed to enable VRDE while VM is running."
        fi
    fi

    # Get current VRDE port
    VRDE_PORT=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep -i '^vrdeport=' | cut -d'=' -f2 | tr -d '"')

    # If port is -1 or 0 or not set or 3389 → generate random port
    if [[ -z "$VRDE_PORT" || "$VRDE_PORT" == "-1" || "$VRDE_PORT" == "0" || "$VRDE_PORT" == "3389" ]]; then
        echo "Searching for a free random VRDE port..."

        while true; do
            VRDE_PORT=$(( RANDOM % (MAX_PORT - MIN_PORT + 1) + MIN_PORT ))


	    # check in .vbox configs
            local found_conflict="0"
	    while IFS= read -r vboxfile; do
                if grep -q "<VRDEPort>${VRDE_PORT}</VRDEPort>" "$vboxfile"; then
                    found_conflict="1"
                    break
                fi
            done < <(find "${HOME}/VirtualBox VMs" -type f -name "*.vbox")

            if [[ "$found_conflict" == "1" ]]; then
                echo "Port ${VRDE_PORT} already used in VM configs. Trying another..."
                continue
            fi

            # check if port in use on system
            if netstat -tuln 2>/dev/null | grep -q ":${VRDE_PORT} "; then
                echo "Port ${VRDE_PORT} already listening on system. Trying another..."
                continue
            fi

            if ss -tuln 2>/dev/null | grep -q ":${VRDE_PORT} "; then
                echo "Port ${VRDE_PORT} already listening on system. Trying another..."
                continue
            fi

            # all good
            echo "Found free VRDE port: $VRDE_PORT"
            break
        done

        if [[ "$VMSTATE" == "poweroff" ]]; then
            VBoxManage modifyvm "$VM_NAME" --vrdeport "$VRDE_PORT" || error_exit "Failed to set VRDE port."
        else
            VBoxManage controlvm "$VM_NAME" vrdeport "$VRDE_PORT" || error_exit "Failed to set VRDE port while VM is running."
        fi
    fi

    if [[ "$VMSTATE" == "poweroff" ]]; then
        echo "Starting VM $VM_NAME in headless mode..."
        VBoxManage startvm "$VM_NAME" --type headless || error_exit "Failed to start VM."
        sleep 3
    fi

    local IPADDR
    IPADDR=$(ip -o -4 addr show | awk '!/ lo / && !/vboxnet/ && !/virbr/ {print $4}' | cut -d/ -f1 | head -n1)

    echo
    echo "---------------------------------------------------"
    echo "VRDE is enabled for VM '$VM_NAME'."
    echo "Connect via RDP client to:"
    echo
    echo "    rdesktop $IPADDR:$VRDE_PORT"
    echo
    echo "Or any other RDP client."
    echo "---------------------------------------------------"
}

#--------------------------------------------
# Function: start
#--------------------------------------------
start_vm() {
    local VM_NAME=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."
    check_vm_exists "$VM_NAME"

    VBoxManage startvm "$VM_NAME" --type headless || error_exit "Failed to start VM."
    echo "VM '$VM_NAME' started."
}

#--------------------------------------------
# Function: stop
#--------------------------------------------
stop_vm() {
    local VM_NAME=""
    local MODE="acpi"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            --mode) MODE="$2"; shift 2 ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."
    check_vm_exists "$VM_NAME"

    if [[ "$MODE" == "acpi" ]]; then
        VBoxManage controlvm "$VM_NAME" acpipowerbutton || error_exit "Failed to send ACPI shutdown."
	VBoxManage controlvm "$VM_NAME" vrde off
    elif [[ "$MODE" == "poweroff" ]]; then
        VBoxManage controlvm "$VM_NAME" poweroff || error_exit "Failed to power off VM."
	VBoxManage modifyvm "$VM_NAME" --vrde off
    else
        error_exit "Invalid mode. Use 'acpi' or 'poweroff'."
    fi

    echo "VM '$VM_NAME' stopped via $MODE."
}

#--------------------------------------------
# Function: restart/reset
#--------------------------------------------
restart_vm() {
    local VM_NAME=""
    local HARD_RESET=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            --reset) HARD_RESET=1; shift ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."
    check_vm_exists "$VM_NAME"

    if [[ $HARD_RESET -eq 1 ]]; then
        echo "Performing hard reset of VM '$VM_NAME'..."
        VBoxManage controlvm "$VM_NAME" poweroff || error_exit "Failed to power off VM."
        sleep 3
        VBoxManage startvm "$VM_NAME" --type headless || error_exit "Failed to start VM."
        echo "VM '$VM_NAME' was hard reseted."
    else
        echo "Performing soft restart of VM '$VM_NAME'..."
        VBoxManage controlvm "$VM_NAME" reset || error_exit "Failed to reset VM."
        echo "VM '$VM_NAME' was soft restarted."
    fi
}

#--------------------------------------------
# Function: import_vm
#--------------------------------------------
import_vm() {
    local VM_NAME=""
    local VDI_PATH=""
    local ORIGINAL_CONFIG_PATH="" # Renamed to avoid confusion
    local NET_TYPE="bridged"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            --disk) VDI_PATH="$2"; shift 2 ;;
            --config) ORIGINAL_CONFIG_PATH="$2"; shift 2 ;;
            --net) NET_TYPE="$2"; shift 2 ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    # --- VALIDATION ---
    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."
    [[ -z "$VDI_PATH" ]] && error_exit "Please provide --disk VDI_PATH."
    [[ -z "$ORIGINAL_CONFIG_PATH" ]] && error_exit "Please provide --config CONFIG_PATH."

    VDI_PATH=$(realpath "$VDI_PATH") || error_exit "Failed to resolve VDI path."
    ORIGINAL_CONFIG_PATH=$(realpath "$ORIGINAL_CONFIG_PATH") || error_exit "Failed to resolve config path."

    [[ ! -f "$VDI_PATH" ]] && error_exit "Disk file does not exist: $VDI_PATH"
    [[ ! -f "$ORIGINAL_CONFIG_PATH" ]] && error_exit "Config file does not exist: $ORIGINAL_CONFIG_PATH"

    check_vm_not_exists "$VM_NAME"

    echo "Importing VM: $VM_NAME"
    echo "Original disk path: $VDI_PATH"
    echo "Original config path: $ORIGINAL_CONFIG_PATH"

    # --- PREPARE TARGET LOCATIONS ---
    local VM_CONF_DIR="${HOME}/VirtualBox VMs/${VM_NAME}"
    local TARGET_VDI_PATH="${VM_DIR}/${VM_NAME}.vdi"
    local TARGET_CONFIG_PATH="${VM_CONF_DIR}/${VM_NAME}.vbox"

    mkdir -p "$VM_CONF_DIR" || error_exit "Failed to create VM directory at ${VM_CONF_DIR}."

    # --- PROCESS DISK ---
    if [[ "$VDI_PATH" != "$TARGET_VDI_PATH" ]]; then
        echo "Moving disk to $TARGET_VDI_PATH..."
        mv "$VDI_PATH" "$TARGET_VDI_PATH" || error_exit "Failed to move disk."
    else
        echo "Disk already in correct location."
    fi
    VDI_PATH="$TARGET_VDI_PATH" # Update VDI_PATH to the new location

    VBoxManage closemedium disk "$VDI_PATH" &>/dev/null || true

    echo "Setting new UUID for disk $VDI_PATH..."
    VBoxManage internalcommands sethduuid "$VDI_PATH" || error_exit "Failed to change disk UUID."

    local NEW_UUID
    NEW_UUID=$(VBoxManage showmediuminfo "$VDI_PATH" | awk -F': +' '/^UUID:/ {print $2}')
    echo "New disk UUID: {$NEW_UUID}"

    # --- PROCESS CONFIG FILE ---
    # 1. Get old info from the ORIGINAL config BEFORE any changes
    echo "Reading old parameters from $ORIGINAL_CONFIG_PATH..."
    local OLD_UUID
    OLD_UUID=$(grep -oP 'HardDisk uuid="\K{[^}]+}' "$ORIGINAL_CONFIG_PATH" | head -n1)
    echo "Old disk UUID from config: $OLD_UUID"

    local OLD_NAME
    OLD_NAME=$(grep '<Machine' "$ORIGINAL_CONFIG_PATH" | sed -n 's/.*name="\([^"]*\)".*/\1/p')
    echo "Old VM name from config: $OLD_NAME"

    # 2. Copy config file to the new location
    echo "Copying config to $TARGET_CONFIG_PATH..."
    cp "$ORIGINAL_CONFIG_PATH" "$TARGET_CONFIG_PATH" || error_exit "Failed to copy config."
    
    # 3. Modify the NEW config file IN-PLACE
    echo "Updating configuration in $TARGET_CONFIG_PATH..."
    
    # Update disk UUID
    if [[ -n "$OLD_UUID" ]]; then
        sed -i "s|$OLD_UUID|{$NEW_UUID}|g" "$TARGET_CONFIG_PATH" || error_exit "Failed to update UUID in config."
    fi
    
    # Update disk path: find any 'location' attribute ending in .vdi within a HardDisk tag and replaces it.
    echo "Updating disk path in config (robust method)..."
    sed -i "/<HardDisk/s#location=\"[^\"]*\\.vdi\"#location=\"$VDI_PATH\"#" "$TARGET_CONFIG_PATH" || error_exit "Failed to update disk path in config."

    # Update VM name
    if [[ -n "$OLD_NAME" ]]; then
        sed -i "s/name=\"$OLD_NAME\"/name=\"$VM_NAME\"/" "$TARGET_CONFIG_PATH" || error_exit "Failed to update VM name in config."
    fi

    # *** CRITICAL FIX 1 ***: Remove the reference to the old settings file.
    echo "Clearing old settingsFile attribute..."
    sed -i 's/ settingsFile="[^"]*"//' "$TARGET_CONFIG_PATH" || error_exit "Failed to clear settingsFile attribute."

    # --- REGISTER AND CONFIGURE VM ---
    echo "Registering VM..."
    VBoxManage registervm "$TARGET_CONFIG_PATH" || error_exit "Failed to register VM."

    CONTROLLER=$(get_sata_controller_name "$TARGET_CONFIG_PATH")
    echo "Attaching disk on controller $CONTROLLER..."
    VBoxManage storageattach "$VM_NAME" \
        --storagectl "$CONTROLLER" \
        --port 0 --device 0 --type hdd --medium "$VDI_PATH" \
        --nonrotational on || error_exit "Failed to attach disk."

    echo "Configuring network..."
    if [[ "$NET_TYPE" == "bridged" ]]; then
        local IFACE
        IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -Ev 'lo|vboxnet|virbr' | head -n1)
        [[ -z "$IFACE" ]] && error_exit "No suitable bridged interface found."
        VBoxManage modifyvm "$VM_NAME" --nic1 bridged \
            --bridgeadapter1 "$IFACE" || error_exit "Failed to modify network."
    else
        VBoxManage modifyvm "$VM_NAME" --nic1 "$NET_TYPE" || error_exit "Failed to modify network."
    fi

    echo "VM '$VM_NAME' imported successfully."
}

#--------------------------------------------
# Function: list
#--------------------------------------------
list_vms() {
    echo "Running VMs:"
    VBoxManage list runningvms

    echo
    echo "Other VMs:"
    VBoxManage list vms | while read -r line; do
        VM=$(echo "$line" | awk '{print $1}' | tr -d '"')
        if ! VBoxManage showvminfo "$VM" | grep -q "running (since"; then
            echo "$VM"
        fi
    done
}

#--------------------------------------------
# Function: list_autostart
#--------------------------------------------
list_autostart_vms() {
    echo "List from VBoxManage showvminfo:"
    	VBoxManage list vms | while read -r line; do
        VM=$(echo "$line" | awk '{print $1}' | tr -d '"')
        if VBoxManage showvminfo "$VM" | grep -q "Autostart Enabled:[[:space:]]*enabled"; then
            echo "$VM"
        fi
    done

    echo "List from root.start"
    cat /etc/vbox/autostart/root.start
}

#--------------------------------------------
# Function: enable_autostart
#--------------------------------------------
enable_autostart_vm() {
    local VM_NAME=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."
    check_vm_exists "$VM_NAME"

    VBoxManage modifyvm "$VM_NAME" --autostart-enabled on || error_exit "Failed to enable autostart."
    echo "VM '$VM_NAME' autostart enabled."
    # Додати VM у root.start, якщо її ще нема
    grep -qxF "$VM_NAME" /etc/vbox/autostart/root.start || \
        echo "$VM_NAME" | sudo tee -a /etc/vbox/autostart/root.start > /dev/null

    echo "VM '$VM_NAME' autostart enabled and added to root.start"
}

#--------------------------------------------
# Function: disable_autostart
#--------------------------------------------
disable_autostart_vm() {
    local VM_NAME=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) VM_NAME="$2"; shift 2 ;;
            *) error_exit "Unknown parameter: $1" ;;
        esac
    done

    [[ -z "$VM_NAME" ]] && error_exit "Please provide --name VM_NAME."
    check_vm_exists "$VM_NAME"

    # Видалити з root.start перед викликом VBoxManage, щоб не було VERR_NO_DIGITS
    if grep -qxF "$VM_NAME" /etc/vbox/autostart/root.start; then
        sudo sed -i "\|^$VM_NAME$|d" /etc/vbox/autostart/root.start
        echo "VM '$VM_NAME' removed from root.start"
    fi

    VBoxManage modifyvm "$VM_NAME" --autostart-enabled off || error_exit "Failed to disable autostart."

    echo "VM '$VM_NAME' autostart disabled."
}

#--------------------------------------------
# Function: help
#--------------------------------------------
print_help() {
    cat << EOF

VM Manager for VirtualBox CLI

Usage:
  vm-manager.sh FUNCTION [parameters]
Functions:
  create
      --name         VM_NAME (required)
      --size         Disk size in GB (default: 20)
      --iso          ISO file from $ISO_DIR
      --boot_order   Comma-separated (default: dvd,disk,net)
      --cpu          Number of CPUs (default: 2)
      --ram          RAM in MB (default: 1024)
      --net          Network type (default: bridged)
  modify
      --name         VM_NAME (required)
      --new_name     NEW_VM_NAME       Rename VM and DISK
      --cpu          Number of CPUs
      --ram          RAM in MB
      --net          Network type
      --iso          ISO filename
      --boot_order   Comma-separated boot order
  destroy --name VM_NAME               Destroy VM (with confirmation)
  config --name VM_NAME [--all]        Show VM configuration (short or full/all)
  clone                                Clone VM to the new one
      --name         VM_NAME (required)
      --new_name     NEW_VM_NAME (required)
  console --name VM_NAME [--off]       Start console for VM, by default [or stop it]
  start --name VM_NAME
  stop --name VM_NAME [--mode acpi|poweroff]
  restart --name VM_NAME [--reset]     Perform soft [or hard] server restart
  import 
      --name         VM_NAME (required)
      --disk         VDI_PATH (required)
      --config       CONFIG_PATH (required)
      --net          Network type (default: bridged)
  list
  list_autostart
  enable_autostart --name VM_NAME
  disable_autostart --name VM_NAME
  help
EOF
}

#--------------------------------------------
# Main logic
#--------------------------------------------

main() {
    FUNC="$1"
    shift || true

    case "$FUNC" in
        create) create_vm "$@" ;;
        modify) modify_vm "$@" ;;
	destroy) destroy_vm "$@" ;;
	config) config_vm "$@" ;;
	clone) clone_vm "$@" ;;
	console) console_vm "$@" ;;
        start) start_vm "$@" ;;
        stop) stop_vm "$@" ;;
	restart) restart_vm "$@" ;;
	import) import_vm "$@" ;;
        list) list_vms ;;
        list_autostart) list_autostart_vms ;;
        enable_autostart) enable_autostart_vm "$@" ;;
        disable_autostart) disable_autostart_vm "$@" ;;
        help|"") print_help ;;
        *) error_exit "Unknown function: $FUNC" ;;
    esac
}

main "$@"

