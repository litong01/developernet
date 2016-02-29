#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1


echo "racoon racoon/config_mode select direct" | debconf-set-selections

apt-get install -qqy dkms ipsec-tools debconf-utils
apt-get install -qqy graphviz autoconf automake bzip2 debhelper \
  dh-autoreconf libssl-dev libtool openssl procps python-all python-qt4 \
  python-twisted-conch python-zopeinterface python-six
apt-get install -qqy racoon
  
dpkg -i openvswitch-common_2.5.90-1_amd64.deb
dpkg -i openvswitch-switch_2.5.90-1_amd64.deb
dpkg -i openvswitch-datapath-dkms_2.5.90-1_all.deb
dpkg -i python-openvswitch_2.5.90-1_all.deb
dpkg -i openvswitch-ipsec_2.5.90-1_amd64.deb
dpkg -i openvswitch-pki_2.5.90-1_all.deb
dpkg -i openvswitch-vtep_2.5.90-1_amd64.deb
dpkg -i ovn-common_2.5.90-1_amd64.deb
dpkg -i ovn-central_2.5.90-1_amd64.deb
dpkg -i ovn-host_2.5.90-1_amd64.deb

modprobe -r vport_geneve
modprobe -r openvswitch

modprobe openvswitch
modprobe vport_geneve
