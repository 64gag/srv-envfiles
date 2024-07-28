#!/usr/bin/env bash

source "$(dirname "$0")/srv-lib.doc.sh"

venv_id=2008
venv_user_name=lxc-2008-ubuntu-srep

venv_template=trinity-hdd-pve-isos-encrypted:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst
venv_storage=trinity-hdd-pve-vms-encrypted
venv_rootfs=trinity-hdd-pve-vms-encrypted:16
venv_cores=12
venv_memory_MB=$((16 * 1024))
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
        #rm -rf "${venv_mp0_host_dir}" # NOTE commented for nextcloud because it is quite dangerous...
        ;;
    "guest-create")
        apt-get update && apt-get upgrade -y
        apt-get install -y avahi-daemon
        apt-get install -y vim git devscripts
        apt-get install -y debhelper cmake libsqlite3-dev libgtest-dev libgmock-dev # from libsrep debian/control
        apt-get install -y debhelper cmake libsqlite3-dev libboost-system-dev libboost-filesystem-dev libboost-filesystem1.74.0 # from libfsrep debian/control
        apt-get install -y ruby ruby-fcgi apache2 libapache2-mod-fcgid # from www-srs debian/control

        #apt-get install -y ruby-fcgi # Removed from www-srs debian/control because it is broken, install manually instead:
        apt-get install -y libfcgi libfcgi-dev ruby-dev
        gem install fcgi

        mkdir -p "${venv_mp0_guest_dir}/git"
        cat <<- EOF >> "/etc/motd"
        This container is intended to be a full dev and deployment workspace.

        For each of these directories:
        cd /venv/git/libsrep
        cd /venv/git/srep-backend
        cd /venv/git/www-srs

        Do:
        /venv/git/ki-devscripts/opt/kyma/ki/bin/kibuild.doc.sh deb && dpkg -i debian/*.deb && /venv/git/ki-devscripts/opt/kyma/ki/bin/kibuild.doc.sh clean

        a2enmod fcgid
        a2dissite 000-default.conf
        a2ensite www-srs
        systemctl reload apache2

        systemctl restart apache2
EOF
        ;;
    start|stop|destroy|mount|unmount|exec)
        action=$1
        shift
        pct ${action} ${venv_id} "$@"
        ;;
    *)
        echo "${script_basename}: Unsupported or unknown action $1"
        ;;
esac
