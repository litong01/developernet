#!/usr/bin/env bash

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

service apache2 restart

source ~/admin-openrc.sh

echo "Setting up public and private network..."

neutron net-create internet --shared --router:external True \
  --provider:physical_network public \
  --provider:network_type flat

neutron subnet-create internet $leap_public_net_cidr --name internet-subnet \
  --allocation-pool start=$leap_public_net_start_ip,end=$leap_public_net_end_ip \
  --dns-nameserver 8.8.4.4 --gateway $leap_public_net_gateway

source ~/demo-openrc.sh
neutron net-create demonet

neutron subnet-create demonet 10.0.10.0/24 --name demonet-subnet \
  --dns-nameserver 8.8.4.4 --gateway 10.0.10.1

neutron router-create demo-router

neutron router-interface-add demo-router demonet-subnet

neutron router-gateway-set demo-router internet

echo "Init-node-01 is now complete!"
