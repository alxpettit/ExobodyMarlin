#!/usr/bin/env bash

target_part="/dev/disk/by-id/usb-Generic_MassStorageClass_000000001536-0:0-part1"

ssh root@yuri-mech mkdir -p /mnt/target
ssh root@yuri-mech mount "$target_part" /mnt/target
ssh root@yuri-mech rm /mnt/target/*.bin
rsync -P $(echo .pio/build/STM32F103RET6_creality/firmware-*.bin | choose -1) root@yuri-mech:/mnt/target/
while true; do
ssh root@yuri-mech umount "$target_part" || exit
done
# ssh root@yuri-mech fsck "$target_part"

