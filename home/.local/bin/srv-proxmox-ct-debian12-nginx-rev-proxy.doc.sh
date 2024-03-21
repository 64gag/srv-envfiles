#!/usr/bin/env bash
ct_vmid=201
ct_ostemplate=trinity-hdd-pve-isos:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst
ct_hostname=ct-debian12-nginx-rev-proxy
ct_storage=trinity-hdd-pve-vms
ct_rootfs=trinity-hdd-pve-vms:1
ct_cores=2
ct_memory=2048
ct_net=name=eth0,bridge=vmbr0,ip=dhcp
ct_pubkeys=/root/.ssh/authorized_keys
ct_onboot=1
ct_unprivileged=1
ct_features=nesting=1

case $1 in
    "host-install")
        pct create ${ct_vmid} "${ct_ostemplate}" \
            --hostname ${ct_hostname} \
            --storage ${ct_storage} \
            --rootfs ${ct_rootfs} \
            --cores ${ct_cores} \
            --memory ${ct_memory} \
            --net0 "${ct_net}" \
            --ssh-public-keys "${ct_pubkeys}" \
            --onboot ${ct_onboot} \
            --unprivileged ${ct_unprivileged} \
            --features "${ct_features}"
        ;;
    "guest-install")
        apt update && apt upgrade -y && apt install -y nginx
        #apt install -y avahi-daemon
        cat << EOF > /etc/nginx/sites-available/cloud.kymasoft.com
server {
    listen 80;
    server_name cloud.kymasoft.com;

    location / {
        proxy_pass http://192.168.1.67:3000;
        include proxy_params;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
        ln -s /etc/nginx/sites-available/cloud.kymasoft.com /etc/nginx/sites-enabled/
        systemctl reload nginx
        ;;
    start|stop|destroy)
        pct "$1" "${ct_vmid}"
        ;;
    *)
        echo "Unknown action $1"
        ;;
esac
