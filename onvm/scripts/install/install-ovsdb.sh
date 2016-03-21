#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

echo "racoon racoon/config_mode select direct" | debconf-set-selections

apt-get install -qqy "$leap_aptopt" dkms ipsec-tools debconf-utils
apt-get install -qqy "$leap_aptopt" graphviz autoconf automake bzip2 \
  debhelper dh-autoreconf libssl-dev libtool openssl procps python-all \
  python-qt4 python-twisted-conch python-zopeinterface python-six
apt-get install -qqy "$leap_aptopt" racoon

debloc='/onvm/debpackages'
dpkg -i "$debloc"/openvswitch-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-switch_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-datapath-dkms_2.5.90-1_all.deb
dpkg -i "$debloc"/python-openvswitch_2.5.90-1_all.deb
dpkg -i "$debloc"/openvswitch-ipsec_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-pki_2.5.90-1_all.deb
dpkg -i "$debloc"/openvswitch-vtep_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-central_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-host_2.5.90-1_amd64.deb

modprobe -r vport_geneve
modprobe -r openvswitch

modprobe openvswitch
modprobe vport_geneve