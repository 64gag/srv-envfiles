#!/usr/bin/env bash

if [ -z "$SRV_OS" ]; then
    echo "This script requires you to select an OS via the env var SRV_OS"
    echo "Supported values: ubuntu, debian, proxmox-on-debian, proxmox"
    exit 1
fi

if [ -z "$SRV_HOSTNAME" ]; then
    echo "This script expects you to select a hostname via the env var SRV_HOSTNAME"
    exit 1
fi

source "$(dirname "$0")/srv-lib.doc.sh"

_SRV_STEP=""

if [[ "$SRV_STEP" =~ ^[0-9]+$ ]]; then
    case "$SRV_OS" in
        debian|ubuntu)
            _SRV_STEPS_DEBIAN=(
                "DEB_BASED_APT_INSTALL_SRV_STACK"
                "LINUX_CMD_CONFIGURE_IOMMU_PT"
                "SRV_BASIC_COMMON_CONFIG"
                "DEB_CONFIGURE_NET_INTERFACES"
                "DEB_APT_INSTALL_DOCKER"
                "ZFS_CREATE_POOLS"
                "ZFS_CREATE_DATASETS"
                "DEB_PIP_INSTALL_LATEST_DUPLICITY"
                "DEB_BASED_CONFIGURE_DROPBEAR_SSH_LUKS_UNLOCK"
                "APPEND_CHEATSHEET_TO_MOTD"
            )

            array_length=${#_SRV_STEPS_DEBIAN[@]}
            if (( SRV_STEP >= 0 && SRV_STEP < array_length )); then
                _SRV_STEP=${_SRV_STEPS_DEBIAN[SRV_STEP]}
            fi
            ;;
        proxmox-on-debian)
            _SRV_STEPS_PROXMOX_ON_DEBIAN=(
                "PROX_ON_DEB_APT_INSTALL_PROX_KERNEL"
                "DEB_BASED_APT_INSTALL_SRV_STACK"
                "PROX_ON_DEB_APT_INSTALL_PROX_ONCE_ON_KERNEL"
                "LINUX_CMD_CONFIGURE_IOMMU_PT"
                "SRV_BASIC_COMMON_CONFIG"
                "DEB_CONFIGURE_NET_INTERFACES"
                "DEB_APT_INSTALL_DOCKER"
                "ZFS_CREATE_POOLS"
                "ZFS_CREATE_DATASETS"
                "DEB_PIP_INSTALL_LATEST_DUPLICITY"
                "DEB_BASED_CONFIGURE_DROPBEAR_SSH_LUKS_UNLOCK"
                "APPEND_CHEATSHEET_TO_MOTD"
            )

            array_length=${#_SRV_STEPS_PROXMOX_ON_DEBIAN[@]}
            if (( SRV_STEP >= 0 && SRV_STEP < array_length )); then
                _SRV_STEP=${_SRV_STEPS_PROXMOX_ON_DEBIAN[SRV_STEP]}
            fi
            ;;
        proxmox)
            _SRV_STEPS_PROXMOX=(
                "DEB_BASED_APT_INSTALL_SRV_STACK"
                "LINUX_CMD_CONFIGURE_IOMMU_PT"
                "SRV_BASIC_COMMON_CONFIG"
                "DEB_APT_INSTALL_DOCKER"
                "ZFS_CREATE_POOLS"
                "ZFS_CREATE_DATASETS"
                "DEB_PIP_INSTALL_LATEST_DUPLICITY"
                "DEB_BASED_CONFIGURE_DROPBEAR_SSH_LUKS_UNLOCK"
                "APPEND_CHEATSHEET_TO_MOTD"
            )

            array_length=${#_SRV_STEPS_PROXMOX[@]}
            if (( SRV_STEP >= 0 && SRV_STEP < array_length )); then
                _SRV_STEP=${_SRV_STEPS_PROXMOX[SRV_STEP]}
            fi
            ;;
    esac
fi

if [[ "$_SRV_STEP" == "" ]]; then
    cat <<EOF
    === INSTALLING ON UBUNTU ===
    - Use ubuntu liveserver ISO, when asked:
        - Select standard server (not the minimal option)
        - Install OpenSSH server
        - Create a tmp-installer user (to keep actual users in uid range 1000-1999)
        - As of 20241013, the user created by Ubuntu's installer actually takes GID 1000, so it may be good to go
    - Copy SSH keys to be able to log in and get root privileges
    - Finally re-run this script, with root privileges, specifying SRV_STEP=0
    - NOTE: to get this script apt-get update && apt-get install -y git && git clone https://github.com/64gag/srv-envfiles/

    === INSTALLING ON DEBIAN (proxmox or vanilla debian) ===
    From: https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_12_Bookworm

    - Use netinst ISO
    - Append to grub linux command line: ' netcfg/disable_autoconfig=true' (to get asked to configure a static IP address)
    - Hostname '${SRV_HOSTNAME}'
    - Domain 'gaelaguiar.net'
    - Create a tmp-installer user if needed (to keep actual users in uid range 1000-1999)
        - NOTE I could skip the normal user creation by going to the menu with Alt+3
    - Install (check) only 'SSH server' and 'standard system utilities'
    - In '/etc/ssh/sshd_config' temporarily set 'PermitRootLogin yes', then 'systemctl restart sshd' and copy your SSH public key
    - Finally re-run this script specifying SRV_STEP=0
    - NOTE: to get this script apt-get update && apt-get install -y git && git clone https://github.com/64gag/srv-envfiles/

    === INSTALLING FROM PROXMOX ISO ===
    - Much is already installed/configured (do not remember exact instructions)
    - Re-run this script specifying SRV_STEP=0 to run the final steps
EOF
else
    echo "=> Executing step ${_SRV_STEP}"
fi

if [[ "$_SRV_STEP" == "PROX_ON_DEB_APT_INSTALL_PROX_KERNEL" ]]; then
    echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
    wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
    apt-get update && apt-get -y full-upgrade && apt-get install -y proxmox-default-kernel
    apt-get remove -y linux-image-amd64 'linux-image-6.1*'
    echo "NOTE: reboot now if everything went well and then run next SRV_STEP"
    echo "NOTE: Actually I could not boot on the new kernel until I removed previous kernels (during install 2024-04)"
elif [[ "$_SRV_STEP" == "DEB_BASED_APT_INSTALL_SRV_STACK" ]]; then
    apt-get update && apt-get upgrade -y
    apt-get remove -y os-prober
    apt-get update && apt-get install -y bridge-utils vim screen avahi-daemon

    case "$SRV_OS" in
        debian)
            sed -r -i'.BAK' 's/^deb(.*)$/deb\1 contrib/g' /etc/apt/sources.list
            apt-get update && apt-get install -y linux-headers-amd64 zfsutils-linux zfs-dkms zfs-zed
            #modprobe zfs # beware of secure boot!
            ;;
        ubuntu)
            apt-get update && apt-get install -y zfsutils-linux
            ;;
        proxmox-on-debian)
            echo "ZFS stuff is included in proxmox-ve"
            ;;
    esac

    case "$SRV_OS" in
        debian|ubuntu)
            apt-get update && apt-get install -y cpu-checker lxc qemu-kvm libvirt-daemon-system libvirt-clients virtinst
            systemctl status libvirtd
            #sudo usermod -aG libvirt $USER
            #sudo usermod -aG kvm $USER
            ;;
        proxmox-on-debian)
            echo "LXC/KVM stuff is included in proxmox-ve"
            ;;
    esac

    case "$SRV_OS" in
        proxmox-on-debian)
            apt-get install -y proxmox-ve postfix chrony open-iscsi
            ;;
    esac
elif [[ "$_SRV_STEP" == "LINUX_CMD_CONFIGURE_IOMMU_PT" ]]; then
    manual_input_examples_tmp_file=$(mktemp --suffix=-srv)
    cat <<- EOF >> "${manual_input_examples_tmp_file}"
    /etc/default/grub
    GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt"
    (append ' iommu=pt' to whatever is there)

    NOTE!!! See other vim tabs

EOF
    vim "${manual_input_examples_tmp_file}" /etc/default/grub && update-grub && update-initramfs -u -k all
    echo "NOTE: reboot now if everything went well and then run next SRV_STEP"
elif [[ "$_SRV_STEP" == "SRV_BASIC_COMMON_CONFIG" ]]; then
    srv_lib_add_group_and_user 1000 gag
    srv_lib_add_line_to_file_if_not_present "blacklist iwlwifi" /etc/modprobe.d/srv-wifi-blacklist.conf
elif [[ "$_SRV_STEP" == "DEB_CONFIGURE_NET_INTERFACES" ]]; then
    manual_input_examples_tmp_file=$(mktemp --suffix=-srv)
    cat << EOF >> "${manual_input_examples_tmp_file}"
root@${SRV_HOSTNAME}:~# cat /etc/network/interfaces
auto lo
iface lo inet loopback

iface enp5s0 inet manual

auto vmbr0
iface vmbr0 inet static
	address 192.168.1.64/24
	gateway 192.168.1.254
	bridge-ports enp5s0
	bridge-stp off
	bridge-fd 0

source /etc/network/interfaces.d/*

#########################
- The config above is what I had in my last previous install
- Plus the last line, which I see is now added when installing via the v8.1 of proxmox.iso

Which is very similar to:
FROM: https://pve.proxmox.com/wiki/Network_Configuration#_default_configuration_using_a_bridge
source /etc/network/interfaces.d/*

#########################

network:
  version: 2
  ethernets:
    enp5s0:
      dhcp4: no
      dhcp6: no
  bridges:
    br0:
      interfaces: [enp5s0]
      dhcp4: yes
      dhcp6: yes

#########################
In ubuntu server on 20241013, I had to follow:
https://askubuntu.com/questions/1217252/boot-process-hangs-at-systemd-networkd-wait-online
(Add --any to the service file)
It seems like the ethernet interface is never considered "configured" when used as a bridge, which caused a long wait and an error on boot

-> networkctl status -a
[...]
● 2: enp5s0
                   Link File: /usr/lib/systemd/network/99-default.link
                Network File: /run/systemd/network/10-netplan-enp5s0.network
                       State: enslaved (configuring)
[...]

# NOW MANUALLY CONFIGURE THE NETWORK BRIDGE

- To apply:
systemctl restart networking
netplan apply
(or reboot)

NOTE!!! See other vim tabs

EOF
    vim "${manual_input_examples_tmp_file}" /etc/network/interfaces /etc/netplan/*
elif [[ "$_SRV_STEP" == "DEB_APT_INSTALL_DOCKER" ]]; then
    apt-get update

    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do apt-get remove $pkg; done

    case "$SRV_OS" in
        ubuntu)
            dock_os=ubuntu
            ;;
        *)
            dock_os=debian
            ;;
    esac

    apt-get update
    apt-get install ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/${dock_os}/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${dock_os} \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
elif [[ "$_SRV_STEP" == "ZFS_CREATE_POOLS" ]]; then
    echo ""
    echo "# Create the ZFS pools now!"
    echo "(this is very hardware dependant)"
    echo ""
    echo "zpool create -m \"${SRV_ZFS_POOLS_DIR}/${SRV_HDD_POOL_BASENAME}\" -o ashift=12 \"${SRV_HDD_POOL_BASENAME}\" \
        mirror /dev/disk/by-id/ata-WDC_WD40EFZX-68AWUN0_WD-WX72D220JXLZ /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW602V1Z \
        mirror /dev/disk/by-id/ata-WDC_WD40EFZX-68AWUN0_WD-WX32D12FCE4R /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW602HKY"
    echo "zpool create -m \"${SRV_ZFS_POOLS_DIR}/${SRV_SSD_POOL_BASENAME}\" -o ashift=12 \"${SRV_SSD_POOL_BASENAME}\" \
        mirror /dev/disk/by-id/ata-Samsung_SSD_870_EVO_1TB_S626NX0RA17704F /dev/disk/by-id/ata-Samsung_SSD_860_EVO_1TB_S3Z9NS0N507502F"
elif [[ "$_SRV_STEP" == "ZFS_CREATE_DATASETS" ]]; then
    zfs_encryption_passphrase=$(srv_prompt_for_password_with_confirmation "ZFS encryption passphrase setup")

    #TODO GAG re-evaluate the following limit:
    srv_lib_add_line_to_file_if_not_present "options zfs zfs_arc_max=17179869184" /etc/modprobe.d/zfs.conf

    # TODO GAG what is this for? they even fail on boot... how can I achieve the same benefits (if any) without them?
    # TODO GAG Note: I did not enable these on 20241013
    systemctl enable "zfs-import@${SRV_HDD_POOL_BASENAME}.service"
    systemctl enable "zfs-import@${SRV_SSD_POOL_BASENAME}.service"

    echo "${zfs_encryption_passphrase}" | zfs create -o compression=on -o encryption=on -o keyformat=passphrase -o keylocation=prompt ${SRV_SSD_POOL_BASENAME}/${SRV_USERS_DATASET_BASENAME}
    echo "${zfs_encryption_passphrase}" | zfs create -o compression=on -o encryption=on -o keyformat=passphrase -o keylocation=prompt ${SRV_SSD_POOL_BASENAME}/${SRV_LXC_MPS_DATASET_BASENAME}
    echo "${zfs_encryption_passphrase}" | zfs create -o compression=on -o encryption=on -o keyformat=passphrase -o keylocation=prompt ${SRV_SSD_POOL_BASENAME}/${SRV_PVE_VMS_DATASET_BASENAME}
    echo "${zfs_encryption_passphrase}" | zfs create -o compression=on -o encryption=on -o keyformat=passphrase -o keylocation=prompt ${SRV_HDD_POOL_BASENAME}/${SRV_LXC_MPS_DATASET_BASENAME}
    echo "${zfs_encryption_passphrase}" | zfs create -o compression=on -o encryption=on -o keyformat=passphrase -o keylocation=prompt ${SRV_HDD_POOL_BASENAME}/${SRV_USERS_DATASET_BASENAME}
    echo "${zfs_encryption_passphrase}" | zfs create -o compression=on -o encryption=on -o keyformat=passphrase -o keylocation=prompt ${SRV_HDD_POOL_BASENAME}/${SRV_PVE_VMS_DATASET_BASENAME}
    echo "${zfs_encryption_passphrase}" | zfs create -o compression=on -o encryption=on -o keyformat=passphrase -o keylocation=prompt ${SRV_HDD_POOL_BASENAME}/${SRV_PVE_BACKUPS_DATASET_BASENAME}
    echo "${zfs_encryption_passphrase}" | zfs create -o compression=on -o encryption=on -o keyformat=passphrase -o keylocation=prompt ${SRV_HDD_POOL_BASENAME}/${SRV_PVE_ISOS_DATASET_BASENAME}
    echo "${zfs_encryption_passphrase}" | zfs create -o compression=on -o encryption=on -o keyformat=passphrase -o keylocation=prompt ${SRV_HDD_POOL_BASENAME}/${SRV_BACKUPS_DATASET_BASENAME}

    #-o acltype=posix  #TODO GAG I had set acltypes (in the original doc/log spreadsheet), was it for samba? do I really need it?

    # TODO GAG can the following steps be done from the command line?
    # TODO GAG: only print this when installing proxmox
    cat <<EOF
    Then on "datacenter", add each PVE dataset as "Directory" storage.
    - Content: Disk image + containers
        - ID: "${SRV_STORAGE_ID_SSD_PVE_VMS}"
        - Directory: "${SRV_ZFS_POOLS_DIR}/${SRV_SSD_POOL_BASENAME}/${SRV_PVE_VMS_DATASET_BASENAME}"

        - ID: "${SRV_STORAGE_ID_HDD_PVE_VMS}"
        - Directory: "${SRV_ZFS_POOLS_DIR}/${SRV_HDD_POOL_BASENAME}/${SRV_PVE_VMS_DATASET_BASENAME}"

    - Content: VZDump + snippets
        - ID: "${SRV_STORAGE_ID_HDD_PVE_BACKUPS}"
        - Directory: "${SRV_ZFS_POOLS_DIR}/${SRV_HDD_POOL_BASENAME}/${SRV_PVE_BACKUPS_DATASET_BASENAME}"

    - Content: ISO image + container template
        - ID: "${SRV_STORAGE_ID_HDD_PVE_ISOS}"
        - Directory: "${SRV_ZFS_POOLS_DIR}/${SRV_HDD_POOL_BASENAME}/${SRV_PVE_ISOS_DATASET_BASENAME}"
EOF
    zfs mount -l -a
elif [[ "$_SRV_STEP" == "DEB_PIP_INSTALL_LATEST_DUPLICITY" ]]; then
    # TODO GAG install all this in an LXC container?
    apt-get update && apt-get install -y \
        build-essential \
        x86_64-linux-gnu-gcc \
        intltool \
        lftp \
        librsync-dev \
        libffi-dev \
        libssl-dev \
        openssl \
        par2 \
        python3-dev \
        python3-pip \
        python3-venv \
        python3 \
        rclone \
        rsync \
        rdiff \
        tzdata

    python3 -m venv /opt/python3-venv
    source /opt/python3-venv/bin/activate
    /opt/python3-venv/bin/pip3 install googleapi
    /opt/python3-venv/bin/pip3 install google-auth-oauthlib
    /opt/python3-venv/bin/pip3 install duplicity
    /opt/python3-venv/bin/pip3 install fasteners
    cat <<EOF
    ##############################################
    # IF THE COMMANDS ABOVE FAILED, TRY AGAIN!!! #
    ##############################################

    # Create a google app, to upload with it to your google drive"
    - https://console.cloud.google.com/welcome?project=PROJECT"
    - "APIs & Services" -> "Credentials"
    - Put the JSON in /zfs/hdd/srv-backups-encrypted/.duplicity/
    # Configuration
    - Install the config etc/srv/srv-backup.doc.sh.conf file in this repository
    - Then the simplest thing to do is to run a backup on a PC with a graphic environment once, since you will be prompted to approve the app via a web browser prompt
    - scp /zfs/hdd/srv-backups-encrypted/.duplicity/credentials root@${SRV_HOSTNAME}.local:/zfs/hdd/srv-backups-encrypted/.duplicity/
    - Do NOT forget: chmod -R o-rwx /zfs/hdd/srv-backups-encrypted/.duplicity/
EOF
    # TODO GAG document restore and other useful knowledge about backups still in the excel file
elif [[ "$_SRV_STEP" == "DEB_BASED_CONFIGURE_DROPBEAR_SSH_LUKS_UNLOCK" ]]; then

    manual_input_examples_tmp_file=$(mktemp --suffix=-srv)
    cat << EOF >> "${manual_input_examples_tmp_file}"
SSH:
- Create a key in another PC: ssh-keygen -t rsa -b 4096 -f ~/.ssh/dropbear_initramfs_key
- Copy it to the server: scp ~/.ssh/dropbear_initramfs_key.pub root@${SRV_HOSTNAME}.local:/tmp/
- To connect to dropbear use the same key: ssh -i ~/.ssh/dropbear_initramfs_key ...

Password:
- TODO

Dropbear options:
- In file: /etc/dropbear/initramfs/dropbear.conf
- Port, forwarding, password, set command to run automatically, etc can be configured if needed (I left it at defaults/empty)
DROPBEAR_OPTIONS="-I 180 -j -k -p 2222 -s -c cryptroot-unlock"

Load modules during initramfs
- Find the kernel module used for ethernet with: lspci -nnk | grep -i ethernet -A2
- Add a line with the module to the file: /etc/initramfs-tools/modules

Configure static IP for initramfs (untested):
- In file: /etc/initramfs-tools/initramfs.conf
- Add a line like: IP=192.168.1.64::192.168.1.254:255.255.255.0:${SRV_HOSTNAME}

NOTE!!! See other vim tabs

EOF
    vim "${manual_input_examples_tmp_file}" /etc/dropbear/initramfs/dropbear.conf /etc/initramfs-tools/modules /etc/initramfs-tools/initramfs.conf
    apt-get update && apt-get install -y dropbear-initramfs

    if [ -f /tmp/dropbear_initramfs_key.pub ]; then
        cat /tmp/dropbear_initramfs_key.pub >> /etc/dropbear/initramfs/authorized_keys
        chmod 0600 /etc/dropbear/initramfs/authorized_keys
        rm /tmp/dropbear_initramfs_key.pub
    fi

    update-initramfs -u
elif [[ "$_SRV_STEP" == "APPEND_CHEATSHEET_TO_MOTD" ]]; then
    cat <<- EOF >> "/etc/motd"
    # SRV

    ## Backup
    - source /opt/python3-venv/bin/activate && ~/srv-envfiles/home/.local/bin/srv-backup.doc.sh | tee -a /var/log/srv-backup.doc.sh.log
    - Be ready to enter your encryption key
    - It is probably a good idea to configure this to run automatically but, if launched manually and remotely, detach somehow (ie. screen)

    ## Restore
    - Recover files important for restore
       (.duplicity files are not included in backup, but the client_secret_*.json file can be re-downloaded and the token exchange can be run again)
        - scp -r root@${SRV_HOSTNAME}:/zfs/hdd/srv-backups-encrypted/.duplicity .
        - scp -r root@${SRV_HOSTNAME}:/etc/srv .
    - duplicity --path-to-restore etc/passwd gdrive://816926805381-23drc1c07eba47u5hjsjpemhrgi53lku.apps.googleusercontent.com/pve-backups-duplicity/backup-cfg-5-srv--duplicity-latest-pip--include-tmp?myDriveFolderID=root passwd
    - For a re-install, re-create users as in file '/etc/passwd'

    ## Misc
    - zfs mount -l -a
    - modprobe -r amdgpu

EOF
    case "$SRV_OS" in
        proxmox*)
            cat <<- EOF >> "/etc/motd"
    ## LXC
    - Update LXC templates with: pveam update
    - List available LXC templates: pveam list hdd-pve-isos-encrypted
EOF
            ;;
    esac
fi

#    echo "=== SUBORDINATE USER/GROUP IDS ==="
#    echo ""
#    cat /etc/subuid
#    echo ""
#    cat /etc/subgid
#    echo ""
#    echo ""
#    echo "The syntax 'root:100000:65536' means:"
#    echo "- containers launched by root (user or group depending on the file)"
#    echo "- will have an (U/I)ID namespace mapped on/to the host IDs starting from 100000"
#    echo "- and of a size/count/capacity of 65536"
#    echo ""
#    echo "Note that 'groupadd' and 'useradd' automatically add non-overlapping entries to these files"
