#!/usr/bin/env bash

apt-get update

apt-get install -qqy git python-dev
apt-get install -qqy build-essential fakeroot

echo 'Build OVN Binaries...'
git clone https://github.com/openvswitch/ovs /opt/ovsbuild/ovs
cd /opt/ovsbuild/ovs
apt-get install -qqy graphviz autoconf automake debhelper dh-autoreconf \
   libssl-dev libtool python-all python-qt4 python-twisted-conch
DEB_BUILD_OPTIONS='parallel=8 nocheck' fakeroot debian/rules binary


# Notes to add dns-nameserver and static routing
#  dns-nameservers 8.8.4.4 8.8.8.8
#  up route add -net 0.0.0.0 netmask 0.0.0.0 gw 10.0.2.1