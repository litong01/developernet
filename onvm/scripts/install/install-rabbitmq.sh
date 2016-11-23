#!/usr/bin/env bash
# $1 rabbitmq_password

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

apt-get install -qqy "$leap_aptopt" rabbitmq-server

tun_cidr=$(ip -4 addr show $leap_tunnelnic | awk -F '/' '/inet / {print $1}')
arr=($tun_cidr); my_ip="${arr[1]}"

rabbitmqctl add_user openstack $1

rabbitmqctl set_permissions openstack ".*" ".*" ".*"
rabbitmqctl set_user_tags openstack administrator
rabbitmq-plugins enable rabbitmq_management

echo -e "NODE_IP_ADDRESS=$my_ip" >> /etc/rabbitmq/rabbitmq-env.conf

service rabbitmq-server restart
