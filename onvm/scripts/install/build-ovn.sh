#!/usr/bin/env bash

apt-get update

apt-get install -qqy git python-dev
apt-get install -qqy build-essential fakeroot

echo 'Build OVN Binaries...'
git clone https://github.com/openvswitch/ovs /opt/ovsbuild/ovs
cd /opt/ovsbuild/ovs
apt-get install -qqy graphviz autoconf automake debhelper dh-autoreconf \
   libssl-dev libtool
