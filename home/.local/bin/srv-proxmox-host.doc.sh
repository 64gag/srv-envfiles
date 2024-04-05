#!/usr/bin/env bash

source "$(dirname "$0")/srv-lib.doc.sh"

set -x

echo ""
echo "=== GRUB ==="
echo ""
#Set in /etc/default/grub
#GRUB_TIMEOUT=20
#GRUB_CMDLINE_LINUX_DEFAULT="quiet iommu=pt"
#Then run:
#update-grub
#update-initramfs -u -k all

srv_lib_add_group_and_user 0 gag

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

echo ""
echo "=== ZFS ==="
echo ""

#root@trinity:~/envfiles-srv# cat /etc/modprobe.d/zfs.conf
#options zfs zfs_arc_max=17179869184

zpool create -m /zfs/trinity-hdd -o ashift=12 trinity-hdd mirror /dev/disk/by-id/ata-WDC_WD40EFZX-68AWUN0_WD-WX72D220JXLZ /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW602V1Z mirror /dev/disk/by-id/ata-WDC_WD40EFZX-68AWUN0_WD-WX32D12FCE4R /dev/disk/by-id/ata-ST4000VN006-3CW104_ZW602HKY
systemctl enable zfs-import@trinity-hdd.service # TODO GAG what is this?
# TODO GAG ACLs?

zpool create -m /zfs/trinity-ssd -o ashift=12 trinity-ssd mirror /dev/disk/by-id/XXX-ssd1 /dev/disk/by-id/XXX-ssd2
systemctl enable zfs-import@trinity-ssd.service # TODO GAG what is this?

zfs create trinity-hdd/encrypted -o encryption=on -o keyformat=passphrase

zfs create -o compression=on -o encryption=on -o keyformat=passphrase trinity-ssd/users-encrypted
zfs create -o compression=on -o encryption=on -o keyformat=passphrase trinity-ssd/srv-lxc-mps-encrypted
zfs create -o compression=on -o encryption=on -o keyformat=passphrase trinity-ssd/pve-vms-encrypted
zfs create -o compression=on -o encryption=on -o keyformat=passphrase trinity-hdd/srv-lxc-mps-encrypted
zfs create -o compression=on -o encryption=on -o keyformat=passphrase trinity-hdd/users-encrypted
zfs create -o compression=on -o encryption=on -o keyformat=passphrase trinity-hdd/pve-vms-encrypted
zfs create -o compression=on -o encryption=on -o keyformat=passphrase trinity-hdd/pve-backups-encrypted
zfs create -o compression=on -o encryption=on -o keyformat=passphrase trinity-hdd/pve-isos-encrypted
zfs create -o compression=on -o encryption=on -o keyformat=passphrase trinity-hdd/offsite-backups-encrypted
#-o acltype=posix 
#-o keylocation=file:///tmp/key
rm /tmp/key # TODO GAG

#Then on "datacenter", add each dataset as "Directory" storage. ID: POOL-DATASET, Directory: /zfs/POOL/DATASET
#For pve-isos select Content: ISO image + container template
#For pve-vms, select Content: Disk image + containers
#For pve-backups, select Content: VZDump + snippets


zfs mount -l -a
