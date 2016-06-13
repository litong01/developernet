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