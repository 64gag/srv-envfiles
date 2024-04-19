#!/usr/bin/env bash

source "$(dirname "$0")/srv-lib.doc.sh"

venv_id=2001
venv_user_name=lxc-2001-ubuntu-nextcloud

venv_template=trinity-hdd-pve-isos-encrypted:vztmpl/ubuntu-23.10-standard_23.10-1_amd64.tar.zst
venv_storage=trinity-hdd-pve-vms-encrypted
venv_rootfs=trinity-hdd-pve-vms-encrypted:16
venv_cores=8
venv_memory_MB=$((16 * 1024))
venv_net_if=name="eth0,bridge=vmbr0,hwaddr=$(srv_lib_generate_mac_address ${SRV_NET_MAC_ADDR_PREFIX} $venv_id),ip=dhcp"
venv_pubkeys=/root/.ssh/authorized_keys
venv_start_on_boot=1
venv_lxc_unprivileged=1
venv_features=nesting=1

venv_mps_host_base_dir="${SRV_ZFS_POOLS_DIR}/${SRV_HDD_POOL_BASENAME}/${SRV_LXC_MPS_DATASET_BASENAME}/${venv_id}"
venv_mp0_guest_dir="/venv/nextcloud_datadir"
venv_mp0_host_dir="${venv_mps_host_base_dir}${venv_mp0_guest_dir}"
venv_mp1_guest_dir="/var/lib/docker/volumes"
venv_mp1_host_dir="${venv_mps_host_base_dir}${venv_mp1_guest_dir}"
#TODO GAG what is missing (a mountpoint and some config?) to backup the "database"?

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
            # The main user is 33 (www-data)
            srv_lib_configure_lxc_idmaps $venv_id 100000 65536 33=$venv_id
            #srv_lib_mount_rootfs_and_change_ownership_to_new_lxc_idmaps "${venv_id}" "${venv_user_name}" # No need because I am not mapping the root user
            # What I was using on cloud.kymasoft.com:
            #lxc.idmap: u 0 100000 33
            #lxc.idmap: u 33 1001 1
            #lxc.idmap: u 34 100034 65496
            #lxc.idmap: u 65534 165534 1
            #lxc.idmap: g 0 100000 33
            #lxc.idmap: g 33 1001 1
            #lxc.idmap: g 34 100034 65496
            #lxc.idmap: g 65533 165533 1
            #lxc.idmap: g 65534 165534 1

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
        #rm -rf "${venv_mps_host_base_dir}" # NOTE commented for nextcloud because it is quite dangerous...
        ;;
    "guest-create")
        apt update && apt upgrade -y
        apt install -y avahi-daemon
        srv_lib_install_docker_on_ubuntu

        # What I was using on cloud.kymasoft.com:
        #docker run --sig-proxy=false --name nextcloud-aio-mastercontainer --restart always --detach --publish 80:80 --publish 8080:8080 --publish 8443:8443 --volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config --volume /var/run/docker.sock:/var/run/docker.sock:ro --env NEXTCLOUD_DATADIR="/mnt/nextcloud" nextcloud/all-in-one:latest

        # From (on 20240331) https://github.com/nextcloud/all-in-one/blob/main/reverse-proxy.md#2-use-this-startup-command
        # + custom NEXTCLOUD_DATADIR to ${venv_mp0_guest_dir}
        docker run \
            --init \
            --sig-proxy=false \
            --name nextcloud-aio-mastercontainer \
            --restart always \
            --detach \
            --publish 8080:8080 \
            --env APACHE_PORT=11000 \
            --env APACHE_IP_BINDING=0.0.0.0 \
            --env NEXTCLOUD_DATADIR="${venv_mp0_guest_dir}" \
            --volume "${venv_mp0_host_dir}:${venv_mp0_guest_dir}" \
            --volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
            --volume /var/run/docker.sock:/var/run/docker.sock:ro \
            nextcloud/all-in-one:latest
        echo "- Now go ahead and open the AIO interface: https://ip.address.of.the.host:8080"
        echo "- Then configure the reverse proxy"
        echo "- Finally, submit the domain via the AIO interface"
        echo "root@lxc-2001-ubuntu-nextcloud:~# docker container exec -u 33 nextcloud-aio-nextcloud /var/www/html/occ files:scan --all"
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
