#!/usr/bin/env bash

source "$(dirname "$0")/srv-lib.doc.sh"

venv_id=2099
venv_user_name=lxc-2099-ubuntu-ollama # TODO GAG could get these from filenamei in srv-lib...

venv_template=trinity-hdd-pve-isos-encrypted:vztmpl/ubuntu-23.10-standard_23.10-1_amd64.tar.zst
venv_storage=trinity-hdd-pve-vms-encrypted
venv_rootfs=trinity-hdd-pve-vms-encrypted:16
venv_cores=8
venv_memory_MB=$((64 * 1024))
venv_net_if=name="eth0,bridge=vmbr0,hwaddr=$(srv_lib_generate_mac_address ${SRV_NET_MAC_ADDR_PREFIX} $venv_id),ip=dhcp"
venv_pubkeys=/root/.ssh/authorized_keys
venv_start_on_boot=0
venv_lxc_unprivileged=1
venv_features=nesting=1

venv_mps_host_base_dir="${SRV_ZFS_POOLS_DIR}/${SRV_HDD_POOL_BASENAME}/${SRV_LXC_MPS_DATASET_BASENAME}/${venv_id}"
#venv_mp0_guest_dir="/root/.ollama" # if installed/run as root...
venv_mp0_guest_dir="/usr/share/ollama/.ollama"
venv_mp0_host_dir="${venv_mps_host_base_dir}${venv_mp0_guest_dir}"

script_basename="$(basename "$0")"

case $1 in
    "host-create")
        srv_lib_add_group_and_user "${venv_id}" "${venv_user_name}"

        srv_lib_venv_mp_create "${venv_user_name}" "${venv_mp0_host_dir}"

        pct create ${venv_id} "${venv_template}" \
            --hostname ${venv_user_name} \
            --storage ${venv_storage} \
            --rootfs ${venv_rootfs} \
            --cores ${venv_cores} \
            --memory ${venv_memory_MB} \
            --net0 "${venv_net_if}" \
            --ssh-public-keys "${venv_pubkeys}" \
            --onboot ${venv_start_on_boot} \
            --mp0 "${venv_mp0_host_dir},mp=${venv_mp0_guest_dir}" \
            --unprivileged ${venv_lxc_unprivileged} \
            --features "${venv_features}"

        if [ $? -eq 0 ]; then
            srv_lib_configure_lxc_idmaps $venv_id 100000 65536 999=$venv_id
            #srv_lib_mount_rootfs_and_change_ownership_to_new_lxc_idmaps "${venv_id}" "${venv_user_name}" # not needed because not running as root

            srv_lib_venv_mp_create "${venv_user_name}" "${venv_mp0_host_dir}"

            srv_lib_start_and_create_guest ${venv_id} "$0"
        fi
        ;;
    "host-purge")
        pct stop ${venv_id}
        pct destroy ${venv_id} --purge
        srv_lib_remove_line_from_file "root:${venv_id}:1" "/etc/subuid"
        srv_lib_remove_line_from_file "root:${venv_id}:1" "/etc/subgid"
        srv_lib_remove_group_and_user "${venv_user_name}"
        rm -rf "${venv_mps_host_base_dir}"
        ;;
    "guest-create")
        apt update && apt upgrade -y
        apt install -y avahi-daemon curl
        # TODO GAG do not use this script...? actually understand what it does, what do I need, etc, why ollama uses 995/999?
        curl https://ollama.ai/install.sh | sh

        cat <<- EOF >> "/etc/motd"
        ollama run dolphin-mixtral
        ollama run mixtral:8x7b
        ollama run mixtral:8x22b
        ollama run llama3 "Summarize this file: \$(cat README.md)"

EOF
        ;;
    start|stop|destroy|mount|unmount)
        action=$1
        shift
        pct ${action} ${venv_id} "$@"
        ;;
    *)
        echo "${script_basename}: Unsupported or unknown action $1"
        ;;
esac
