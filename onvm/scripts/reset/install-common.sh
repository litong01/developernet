#!/usr/bin/env bash
# $1 hostname
# $2 public ip eth0
# $3 public ip eth1
# $4 chrony server hostname

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

dpkg --remove-architecture i386
if [ "$leap_uselocalrepo" <> 'yes' ]; then
  apt-get -qqy update
  apt-get -qqy install software-properties-common
  add-apt-repository -y cloud-archive:liberty
fi
apt-key update
apt-get -qqy update
apt-get -qqy install python-openstackclient
apt-get -qqy install chrony

sed -i '/^server /d' /etc/chrony/chrony.conf

if [ "$1" = "$4" ]; then
  echo 'server 1.us.pool.ntp.org iburst' >> /etc/chrony/chrony.conf
else
  echo "server $4 iburst" >> /etc/chrony/chrony.conf
fi

service chrony restart
