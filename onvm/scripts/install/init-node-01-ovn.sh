#!/usr/bin/env bash

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

service apache2 restart

echo "Setting up public and private network..."

source ~/admin-openrc.sh

neutron net-create internet --shared --router:external True \
  --provider:physical_network internet \
  --provider:network_type flat

neutron subnet-create internet $leap_public_net_cidr --name internet-subnet \
  --allocation-pool start=$leap_public_net_start_ip,end=$leap_public_net_end_ip \
  --dns-nameserver 8.8.4.4 --enable-dhcp

source ~/demo-openrc.sh
neutron net-create demonet

neutron subnet-create demonet 10.0.10.0/24 --name demonet-subnet \
  --dns-nameserver 8.8.4.4 --gateway 10.0.10.1

echo "Init-node-01-ovn is now complete!"
