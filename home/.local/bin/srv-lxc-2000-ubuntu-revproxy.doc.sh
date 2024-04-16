#!/usr/bin/env bash

source "$(dirname "$0")/srv-lib.doc.sh"

venv_id=2000
venv_user_name=lxc-2000-ubuntu-revproxy

venv_template=trinity-hdd-pve-isos-encrypted:vztmpl/ubuntu-23.10-standard_23.10-1_amd64.tar.zst
venv_storage=trinity-hdd-pve-vms-encrypted
venv_rootfs=trinity-hdd-pve-vms-encrypted:4
venv_cores=4
venv_memory_MB=4096
venv_net_if=name="eth0,bridge=vmbr0,hwaddr=$(srv_lib_generate_mac_address "BC:24:11:64" $venv_id),ip=dhcp"
venv_pubkeys=/root/.ssh/authorized_keys
venv_start_on_boot=1
venv_lxc_unprivileged=1
venv_features=fuse=1,nesting=1

venv_mps_host_base_dir="${SRV_ZFS_POOLS_DIR}/${SRV_HDD_POOL_BASENAME}/${SRV_LXC_MPS_DATASET_BASENAME}/${venv_id}"
venv_mp0_guest_dir="/etc/nginx/sites-available"
venv_mp0_host_dir="${venv_mps_host_base_dir}${venv_mp0_guest_dir}"
venv_mp1_guest_dir="/etc/letsencrypt"
venv_mp1_host_dir="${venv_mps_host_base_dir}${venv_mp1_guest_dir}"

script_basename="$(basename "$0")"

case $1 in
    "host-create")
        srv_lib_add_group_and_user "${venv_id}" "${venv_user_name}"

        srv_lib_venv_mp_create "${venv_user_name}" "${venv_mp0_host_dir}"
        srv_lib_venv_mp_create "${venv_user_name}" "${venv_mp1_host_dir}"

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
            --mp1 "${venv_mp1_host_dir},mp=${venv_mp1_guest_dir}" \
            --unprivileged ${venv_lxc_unprivileged} \
            --features "${venv_features}"

        if [ $? -eq 0 ]; then
            srv_lib_configure_lxc_idmaps $venv_id 100000 65536 0=$venv_id
            srv_lib_mount_rootfs_and_change_ownership_to_new_lxc_idmaps "${venv_id}" "${venv_user_name}"

            srv_lib_venv_mp_create "${venv_user_name}" "${venv_mp0_host_dir}"
            srv_lib_venv_mp_create "${venv_user_name}" "${venv_mp1_host_dir}"

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
        apt install -y avahi-daemon nginx vim snapd
        snap install --classic certbot
        snap install --classic certbot # First the command sort of fails...
        ln -s /snap/bin/certbot /usr/bin/certbot
        systemctl start nginx
        systemctl enable nginx

        cat << EOF > /etc/nginx/sites-available/srv-example
server {
    listen 80;
    server_name nana-vids.gaelaguiar.net;

    location / {
        proxy_pass http://lxc-debian12-nana-vids.local:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
        echo ""
        echo "# NOW SOME INSTRUCTIONS"
        echo "- To enable a site:"
        echo "ln -s /etc/nginx/sites-available/nana-vids /etc/nginx/sites-enabled/"
        echo "systemctl reload nginx"
        echo ""
        echo "- To manage certificates with certbot:"
        echo "certbot --nginx"
        echo ""
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
