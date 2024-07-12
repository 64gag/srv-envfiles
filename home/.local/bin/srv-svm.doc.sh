#!/usr/bin/env bash
# $0 create --venv-id 3012 --venv-name fr-mich --disk-size-gib 64
source "$(dirname "$0")/srv-lib.doc.sh"

srv_arg_cores=12
srv_arg_memory_gib=24
srv_arg_gpu_pt_enable=0
srv_arg_disk_storage="${SRV_STORAGE_ID_HDD_PVE_VMS}"

srv_action=$1
shift

srv_args_positional=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --cores|-c)
            srv_arg_cores=$2
            shift 2
            ;;
        --memory-gib|-m)
            srv_arg_memory_gib=$2
            shift 2
            ;;
        --disk-storage|-s)
            srv_arg_disk_storage=$2
            shift 2
            ;;
        --disk-size-gib|-d)
            srv_arg_disk_size_gib=$2
            shift 2
            ;;
        --venv-id|-i)
            srv_arg_venv_id=$2
            shift 2
            ;;
        --venv-name|-n)
            srv_arg_venv_name=$2
            shift 2
            ;;
        --gpu|-g)
            srv_arg_gpu_pt_enable=1
            shift
            ;;
        *)
            srv_args_positional+=("$1")
            shift
            ;;
    esac
done

echo "${srv_args_positional[@]}"
srv_common_positional=()
srv_common_positional+=("--cores" ${srv_arg_cores})
srv_common_positional+=("--memory" $((srv_arg_memory_gib * 1024)))
srv_common_positional+=("--hostpci0" ${SRV_HOSTPCI_WIFI})
srv_common_positional+=("--hostpci1" ${SRV_HOSTPCI_USB_MISC})
srv_common_positional+=("--hostpci2" ${SRV_HOSTPCI_MOBO_TOP4})
srv_common_positional+=("--hostpci3" ${SRV_HOSTPCI_AUDIO})

HOSTPCI_GPU="hostpci4"

if [ $srv_arg_gpu_pt_enable -eq 1 ]; then
    srv_common_positional+=("--vga" "none")
    srv_common_positional+=("--${HOSTPCI_GPU}" ${SRV_HOSTPCI_GPU})
else
    srv_common_positional+=("--vga" "qxl,memory=64")
fi

case $srv_action in
    create)
        srv_check_vars_not_null_string srv_arg_venv_id srv_arg_venv_name srv_arg_disk_size_gib
        if [ $? -eq 0 ]; then
            set -x
            qm create ${srv_arg_venv_id} \
                --name "${srv_arg_venv_name}" \
                --machine q35 \
                --bios ovmf \
                --efidisk0 ${SRV_STORAGE_ID_HDD_PVE_VMS}:0,efitype=4m,pre-enrolled-keys=1,size=528K \
                --cpu host \
                --sockets 1 \
                --ostype l26 \
                --scsihw virtio-scsi-single \
                --scsi0 "${srv_arg_disk_storage}:${srv_arg_disk_size_gib},iothread=1" \
                --net0 virtio=$(srv_lib_generate_mac_address ${SRV_NET_MAC_ADDR_PREFIX} $srv_arg_venv_id),bridge=vmbr0,firewall=1 \
                --vga none \
                --balloon 0 \
                --tablet 0 \
                "${srv_common_positional[@]}" \
                "${srv_args_positional[@]}"
        fi
        ;;
    start)
        srv_check_vars_not_null_string srv_arg_venv_id
        if [ $? -eq 0 ]; then
            qm set ${srv_arg_venv_id} "${srv_common_positional[@]}"

            qm start ${srv_arg_venv_id}
            sleep 5

            if [ $srv_arg_gpu_pt_enable -eq 1 ]; then
                qm set ${srv_arg_venv_id} --delete ${HOSTPCI_GPU}
            fi

            qm set ${srv_arg_venv_id} \
                --delete hostpci0,hostpci1,hostpci2,hostpci3 \
                --vga qxl,memory=64
        fi
        ;;
esac

