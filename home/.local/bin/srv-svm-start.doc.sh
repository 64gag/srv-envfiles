#!/usr/bin/env bash

HOSTPCI_GPU="hostpci4"
PCI_GPU="0000:0c:00,pcie=1,x-vga=1"
PCI_WIFI="0000:03:00.0,pcie=1"
PCI_USB_MISC="0000:06:00,pcie=1" # webcam, bluetooth, case's front USB 3.0
PCI_USB_MOBO_TOP_4="0000:0e:00.3,pcie=1"
PCI_AUDIO="0000:0e:00.4,pcie=1"

arg_cores=12
arg_memory_GiB=24
arg_vmid=-1
arg_gpu_pt_enable=0

while [[ $# -gt 0 ]]
do
    case $1 in
        --cores|-c)
            arg_cores=$2
            shift
            shift
            ;;
        --memory-gib|-m)
            arg_memory_GiB=$2
            shift
            shift
            ;;
        --vmid|-i)
            arg_vmid=$2
            shift
            shift
            ;;
        --gpu|-g)
            arg_gpu_pt_enable=1
            shift
            ;;
        *)
            shift
            ;;
    esac
done

qm_set_argv=()
qm_set_argv+=("set" ${arg_vmid})
qm_set_argv+=("--cores" ${arg_cores})
qm_set_argv+=("--memory" $((arg_memory_GiB * 1024)))
qm_set_argv+=("--hostpci0" ${PCI_WIFI})
qm_set_argv+=("--hostpci1" ${PCI_USB_MISC})
qm_set_argv+=("--hostpci2" ${PCI_USB_MOBO_TOP_4})
qm_set_argv+=("--hostpci3" ${PCI_AUDIO})

if [ $arg_gpu_pt_enable -eq 1 ]
then
    qm_set_argv+=("--vga" "none")
    qm_set_argv+=("--${HOSTPCI_GPU}" ${PCI_GPU})
else
    qm_set_argv+=("--vga" "qxl,memory=64")
fi

qm "${qm_set_argv[@]}"

qm start ${arg_vmid}
sleep 5

qm set ${arg_vmid} \
    --delete hostpci0,hostpci1,hostpci2,hostpci3 \
    --vga qxl,memory=64

if [ $arg_gpu_pt_enable -eq 1 ]
then
    qm set ${arg_vmid} --delete ${HOSTPCI_GPU}
fi
