
VM_INST=${1:-snaps}
VM_LIST=()
VM_SELECTED=""

list_vm() {
  echo "Currently availabe VMs are:"
  for VMN in "${!VM_LIST[@]}"; do
    echo "$(expr $VMN + 1). ${VM_LIST[$VMN]}"
  done
}

select_vm() {
  PS3='Please select a VM: '
  select VMN in "${VM_LIST[@]}"; do
    if [[ $REPLY -le "${#VM_LIST[@]}" ]]; then
      VM_SELECTED=$VMN
      echo "$VMN is selected"
      break
    else
      echo "Invalid option."
    fi
  done
}

setup_network() {
  NET_FILE="/etc/netplan/50-cloud-init.yaml"
  echo "\nSetting up network in $VM_SELECTED"
  multipass exec $VM_SELECTED -- sudo sed '$ i nameservers:' $NET_FILE
  multipass exec $VM_SELECTED -- sudo sed '$ i addresses: [1.1.1.1, 8.8.8.8]' $NET_FILE
  multipass exec $VM_SELECTED -- sudo netplan apply
  echo "Network is setup."
  reset_menu_prompt
}

create_vm() {
  printf "Enter a name for new VM: "
  read NEW_VM_NAME
  multipass launch --name $NEW_VM_NAME
  load_vms
  VM_SELECTED=$NEW_VM_NAME
  echo "$VM_SELECTED is created and selected."
}

mount_vm() {
  printf "Enter a folder name to mount in home directory: "
  read MOUNT_TARGET
  multipass exec $VM_SELECTED -- mkdir /home/ubuntu/$MOUNT_TARGET
  multipass mount -u $UID:1000 -g $GID:1000 $PWD/ $VM_SELECTED:/home/ubuntu/$MOUNT_TARGET
}

unmount_vm() {
  multipass unmount $VM_SELECTED
}

reset_vm() {
  unmount_vm
  multipass delete $VM_SELECTED
  multipass purge
  multipass launch --name $VM_SELECTED
  echo "$VM_SELECTED is reset."
}

delete_vm() {
  unmount_vm
  multipass delete $VM_SELECTED
  multipass purge
  echo "$VM_SELECTED is deleted."
  VM_SELECTED=""
  load_vms
}

delete_all() {
  for VMN in "${!VM_LIST[@]}"; do
    multipass unmount ${VM_LIST[$VMN]}
    multipass delete ${VM_LIST[$VMN]}
  done
  multipass purge
  echo "All VMs are deleted."
  VM_SELECTED=""
  load_vms
}

shell_vm() {
  multipass connect $VM_SELECTED
}

load_vms() {
  VM_LIST=($(multipass ls --format csv | sed 1d | cut -d, -f1))
  [[ "${#VM_LIST[@]}" -gt 0 ]] || ( echo "No VMs running." && create_vm )
  [[ "${#VM_LIST[@]}" -eq 1 ]] && VM_SELECTED="${VM_LIST[0]}" && echo "$VM_SELECTED is selected" || ( [[ -z $VM_SELECTED ]] && select_vm )
}

check_network() {
  select_vm
  echo Setting up network in $VM_SELECTED
}

reset_menu_prompt() {
  PS3='Please enter your choice: '
}

menu() {
  while true; do
    reset_menu_prompt
    options=("Create VM" "List VMs" "Change selection" "Shell" "Reset VM" "Delete VM" "Delete all VMs" "Setup Network" "Quit")
    select opt in "${options[@]}"; do
      case $REPLY in
          1|c|C) create_vm; break ;;
          2|l|L) list_vm; break ;;
          3|s|S) select_vm; break;;
          4|h|H) shell_vm; break;;
          5|r|R) reset_vm; break;;
          6|d|D) delete_vm; break;;
          7|a|N) delete_all; break;;
          8|n|N) setup_network; break ;;
          9|q|Q) break 2;;
          *) echo "Invalid option $REPLY";;
      esac
    done
  done
}

main() {
  load_vms
  menu
}

main
