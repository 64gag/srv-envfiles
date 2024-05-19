#!/usr/bin/env bash

source "$(dirname "$0")/srv-lib.doc.sh"

if [[ $SRV_STEP -eq 0 ]]; then
    echo ""
    echo "=== INSTALLING FROM DEBIAN ==="
    echo "From: https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_12_Bookworm"
    echo ""
    echo "- Use netinst"
    echo "- Append to grub linux command line: ' netcfg/disable_autoconfig=true' (to get asked to configure a static IP address)"
    echo "- Hostname trinity"
    echo "- Domain gaelaguiar.net"
    echo "- Create a dummy user if needed (to keep actual users in uid range 1000-1999)"
    echo "- NOTE I could skip the normal user creation by going to the menu with Alt+3"
    echo "- Install (check) only 'SSH server' and 'standard system utilities'"
    echo "- In '/etc/ssh/sshd_config' temporarily set 'PermitRootLogin yes', then 'systemctl restart sshd' and copy your SSH public key"
    echo "- Finally re-run this script specifying SRV_STEP=1"
    echo "- NOTE: to get this script apt update && apt install -y git && git clone https://github.com/64gag/srv-envfiles/"
    echo ""
    echo "=== INSTALLING FROM PROXMOX ==="
    echo "- Finally re-run this script specifying SRV_STEP=5 (from ZFS)"
    echo ""
    echo "=== SUBORDINATE USER/GROUP IDS ==="
    echo ""
    cat /etc/subuid
    cat /etc/subgid
    echo "The syntax 'root:100000:65536' means:"
    echo "- containers launched by root (user or group depending on the file)"
    echo "- will have an (U/I)ID namespace mapped on/to the host IDs starting from 100000"
    echo "- and of a size/count/capacity of 65536"
    echo ""
    echo "Note that 'groupadd' and 'useradd' automatically add non-overlapping entries to these files"
elif [[ $SRV_STEP -eq 1 ]]; then
    srv_lib_add_group_and_user 1000 gag
    srv_lib_add_line_to_file_if_not_present "blacklist iwlwifi" /etc/modprobe.d/srv-wifi-blacklist.conf
    echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
    wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
    apt update && apt -y full-upgrade && apt install -y proxmox-default-kernel
    echo "NOTE: reboot now if everything went well and then run next SRV_STEP"
    echo "NOTE: Actually I could not boot on the new kernel until I removed previous kernels (during install 2024-04)"
elif [[ $SRV_STEP -eq 2 ]]; then
    apt install -y proxmox-ve postfix open-iscsi chrony bridge-utils vim screen avahi-daemon
    apt remove -y linux-image-amd64 'linux-image-6.1*' os-prober
elif [[ $SRV_STEP -eq 3 ]]; then
    manual_input_examples_tmp_file=$(mktemp --suffix=-srv)
    cat <<- EOF >> "${manual_input_examples_tmp_file}"
    /etc/default/grub
    GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt"
    (append ' iommu=pt' to whatever is there)

    NOTE!!! See other vim tabs

EOF
    vim "${manual_input_examples_tmp_file}" /etc/default/grub && update-grub && update-initramfs -u -k all
    echo "NOTE: reboot now if everything went well and then run next SRV_STEP"
elif [[ $SRV_STEP -eq 4 ]]; then
    manual_input_examples_tmp_file=$(mktemp --suffix=-srv)
    cat << EOF >> "${manual_input_examples_tmp_file}"
root@trinity:~# cat /etc/network/interfaces
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

# NOW MANUALLY CONFIGURE THE NETWORK BRIDGE

NOTE!!! See other vim tabs

EOF
    vim "${manual_input_examples_tmp_file}" /etc/network/interfaces && systemctl reboot
elif [[ $SRV_STEP -eq 5 ]]; then
    echo ""
    echo "# Create the ZFS pools now!"
    echo "(this is very hardware dependant)"
    echo ""
    echo "zpool create -m \"${SRV_ZFS_POOLS_DIR}/${SRV_HDD_POOL_BASENAME}\" -o ashift=12 \"${SRV_HDD_POOL_BASENAME}\" \
        mirror /dev/disk/by-id/ata-WDC_WD40EFZX-68AWUN0_WD-WX72D220JXLZ /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW602V1Z \
        mirror /dev/disk/by-id/ata-WDC_WD40EFZX-68AWUN0_WD-WX32D12FCE4R /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW602HKY"
    echo "zpool create -m \"${SRV_ZFS_POOLS_DIR}/${SRV_SSD_POOL_BASENAME}\" -o ashift=12 \"${SRV_SSD_POOL_BASENAME}\" \
        mirror /dev/disk/by-id/ata-Samsung_SSD_870_EVO_1TB_S626NX0RA17704F /dev/disk/by-id/ata-Samsung_SSD_860_EVO_1TB_S3Z9NS0N507502F"
elif [[ $SRV_STEP -eq 6 ]]; then
    zfs_encryption_passphrase=$(srv_prompt_for_password_with_confirmation "ZFS encryption passphrase setup")
    echo "PASSPHRASE = ${zfs_encryption_passphrase}"

    #TODO GAG re-evaluate the following limit:
    srv_lib_add_line_to_file_if_not_present "options zfs zfs_arc_max=17179869184" /etc/modprobe.d/zfs.conf

    # TODO GAG what is this for? they even fail on boot... how can I achieve the same benefits (if any) without them?
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
elif [[ $SRV_STEP -eq 7 ]]; then
    apt install -y python3-full gettext librsync-dev
    #dnf install python3 gettext librsync-devel
    python3 -m venv /opt/python3-venv
    source /opt/python3-venv/bin/activate
    /opt/python3-venv/bin/pip3 install googleapi
    /opt/python3-venv/bin/pip3 install google-auth-oauthlib
    /opt/python3-venv/bin/pip3 install duplicity
    /opt/python3-venv/bin/pip3 install fasteners
    cat <<EOF
    # Create a google app, to upload with it to your google drive"
    - https://console.cloud.google.com/welcome?project=PROJECT"
    - "APIs & Services" -> "Credentials"
    - Put the JSON in /zfs/trinity-hdd/srv-backups-encrypted/.duplicity/
    # Configuration
    - Install the config etc/srv/srv-proxmox-host.doc.sh.conf file in this repository
    - Then the simplest thing to do is to run a backup on a PC with a graphic environment once, since you will be prompted to approve the app via a web browser prompt
    - scp /zfs/trinity-hdd/srv-backups-encrypted/.duplicity/credentials root@trinity.local:/zfs/trinity-hdd/srv-backups-encrypted/.duplicity/
    - Do NOT forget: chmod -R o-rwx /zfs/trinity-hdd/srv-backups-encrypted/.duplicity/
EOF
    # TODO GAG document restore and other useful knowledge about backups still in the excel file
elif [[ $SRV_STEP -eq 8 ]]; then
    # TODO GAG-01-srv-proxmox-host.doc.sh
    echo "https://www.cyberciti.biz/security/how-to-unlock-luks-using-dropbear-ssh-keys-remotely-in-linux/"
    echo "https://www.reddit.com/r/zfs/comments/10qg6yo/openzfs_2171_on_debian_how_to_auto_mount_natively/"
elif [[ $SRV_STEP -eq 100 ]]; then
    cat <<- EOF >> "/etc/motd"
    # SRV

    ## LXC
    - Update LXC templates with: pveam update
    - List available LXC templates: pveam list trinity-hdd-pve-isos-encrypted

    ## Backup
    - source /opt/python3-venv/bin/activate && ~/srv-envfiles/home/.local/bin/srv-backup.doc.sh | tee -a /var/log/srv-backup.doc.sh.log
    - Be ready to enter your encryption key
    - It is probably a good idea to configure this to run automatically but, if launched manually and remotely, detach somehow (ie. screen)
EOF
fi
