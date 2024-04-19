#!/usr/bin/env bash

source "$(dirname "$0")/srv-lib.doc.sh"

venv_id=2002
venv_user_name=lxc-2002-ubuntu-nana-vids

venv_template=trinity-hdd-pve-isos:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst
venv_storage=trinity-hdd-pve-vms
venv_rootfs=trinity-hdd-pve-vms:4
venv_cores=2
venv_memory_MB=2048
venv_net_if=name="eth0,bridge=vmbr0,hwaddr=$(srv_lib_generate_mac_address ${SRV_NET_MAC_ADDR_PREFIX} $venv_id),ip=dhcp"
venv_pubkeys=/root/.ssh/authorized_keys
venv_start_on_boot=0
venv_lxc_unprivileged=1
venv_features=nesting=1

venv_mp0_host_dir="/zfs/trinity-hdd/srv-lxc-mps-encrypted/${venv_id}"
venv_mp0_guest_dir="/venv"

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
            srv_lib_configure_lxc_idmaps $venv_id 100000 65536 0=$venv_id
            srv_lib_mount_rootfs_and_change_ownership_to_new_lxc_idmaps "${venv_id}" "${venv_user_name}"

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
        rm -rf "${venv_mp0_host_dir}"
        ;;
    "guest-create")
        apt update && apt upgrade -y
        apt install -y avahi-daemon
        apt install -y nodejs npm
        npm install express
        npm install multer
        npm install passport passport-local
        npm install mongoose
        npm install bcrypt
        npm install fluent-ffmpeg
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
