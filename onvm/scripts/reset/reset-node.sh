#!/usr/bin/env bash
# $1 hostname
# $2 public ip eth0
# $3 public ip eth1

dir=`mktemp -d` && cd $dir
mkdir source target

mount /dev/vg01/space source

sp=$(lvdisplay | grep /dev/vg00/resetpoint)
if [ "$sp" ];then
   echo 'Ready to remove older resetpoint'
   lvremove -f "/dev/vg00/resetpoint"
fi

lvcreate --size 6G -s -n resetpoint /dev/vg00/vg00-lv01

mount /dev/vg00/resetpoint target

rm -r -f target/*
cd target
tar -xf ../source/cleansystem.tar.gz
#sed -i '/^GRUB_HIDDEN_TIMEOUT/d' etc/default/grub
cd $dir

umount source/
umount target/

lvconvert --merge /dev/vg00/resetpoint

vgchange -a y vg00
