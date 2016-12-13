#!/usr/bin/env bash
# $1 hostname
# $2 public ip eth0
# $3 public ip eth1
# $4 chrony server hostname

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

sp=$(grep $1 /etc/hosts)
if [ ! "$sp" ];then

  #echo -e "\nauto eth1" >> /etc/network/interfaces
  #echo -e "iface eth1 inet static" >> /etc/network/interfaces
  #echo -e "  address $3" >> /etc/network/interfaces
  #echo -e "  netmask 255.255.255.0" >> /etc/network/interfaces

  sed -i '/^127.0.1.1/d' /etc/hosts
  cat /onvm/conf/hosts >> /etc/hosts

  if [ "$leap_uselocalrepo" = 'yes' ]; then
    cp /onvm/conf/sources.list /etc/apt
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 5EDB1B62EC4926EA
  fi

  echo 'Setting up hostname'
  echo -e "$1" > /etc/hostname

fi

