#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

mkdir -p /storage
sp=$(lvdisplay | grep /dev/vg02/storage)
if [ ! "$sp" ];then
  echo 'Ready to create storage'
  lvcreate -l 100%FREE -n storage vg02
  mkfs -t ext4 /dev/vg02/storage
fi

sp=$(mount | grep /storage)
if [ ! "$sp" ]; then
  mount /dev/vg02/storage /storage/
  echo '/dev/mapper/vg02-storage    /storage    ext4    errors=continue    0    0' >> /etc/fstab
fi