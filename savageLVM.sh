#!/usr/bin/env bash
#
# LVM resize script for expanding partitions, handy for virtual machines
# Make sure you edit the volume paths or nothing useful will happen
# 
# Adapted from https://serverfault.com/questions/870594/resize-partition-to-maximum-using-parted-in-non-interactive-mode
# MIT License
#
# Run as root
# Test with ./savageLVM.sh /dev/sdx #
# Execute with ./savageLVM.sh /dev/sdx # apply

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Bye!"
    exit 1
fi

if [[ $# -eq 0 ]] ; then
    echo 'Enter disk to resize (ex: /dev/sdx):'
    exit 1
fi

if [[ $# -eq 1 ]] ; then
    echo 'Enter partition number (ex: 3 for /dev/sda3):'
    exit 1
fi

DISK=$1
PTNUM=$2
APPLY=$3

function resize() # Modify LVM volume path as needed
{
  printf "Running pvresize to sync LVM...\\n"
  pvresize "$DISK$PTNUM" # Inform LVM of partition change
  printf "Running lvextend to fill free space...\\n"
  lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv # Extend partition to fill free space
  printf "Running resize2fs to expand LVM volume...\\n"
  resize2fs /dev/ubuntu-vg/ubuntu-lv # Resize LVM volume to fill free space
  printf "Resize operation complete.\\n"
}

fdisk -l "$DISK""$PTNUM" >> /dev/null 2>&1 || (echo "DISK $DISK$PTNUM not found - please check the name." && exit 1)

# Get disk information, store as variable, convert to MB
CURRENTSIZEB=$(fdisk -l "$DISK""$PTNUM" | grep "Disk $DISK$PTNUM" | cut -d' ' -f5)
CURRENTSIZE=$(("$CURRENTSIZEB" / 1024 / 1024))
MAXSIZEMB=$(printf %s\\n 'unit MB print list' | parted | grep "Disk ${DISK}" | cut -d' ' -f3 | tr -d MB)

echo "Partition will be resized from ${CURRENTSIZE}MB to ${MAXSIZEMB}MB."

if [[ "$APPLY" == "apply" ]] ; then
  parted "${DISK}" resizepart "${PTNUM}" "${MAXSIZEMB}"
  resize
else
  printf "Test complete. Run with 'apply' as the third parameter to execute - ex: ./savageLVM.sh /dev/sda 3 apply\\n"
fi
