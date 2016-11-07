#!/usr/bin/env bash
# $1 sys_password
# $2 public net id
# $3 public net start_ip
# $4 public net end_ip
# $5 public net gateway

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

service apache2 restart

source ~/admin-openrc.sh

echo "Setting up public and private network..."

neutron net-create internet --shared --router:external True \
  --provider:physical_network public \
  --provider:network_type flat

neutron subnet-create internet $2 --name internet-subnet --allocation-pool \
  start=$3,end=$4 --dns-nameserver 8.8.4.4 --gateway $5

source ~/demo-openrc.sh
neutron net-create demonet

neutron subnet-create demonet 10.0.10.0/24 --name demonet-subnet \
  --dns-nameserver 8.8.4.4 --gateway 10.0.10.1

neutron router-create demo-router

neutron router-interface-add demo-router demonet-subnet

neutron router-gateway-set demo-router internet

echo "Init-node-01 is now complete!"
