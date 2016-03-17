#!/usr/bin/env bash
# $1 rabbitmq_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

apt-get install -qqy "$leap_aptopt" rabbitmq-server

rabbitmqctl add_user openstack $1

rabbitmqctl set_permissions openstack ".*" ".*" ".*"
rabbitmqctl set_user_tags openstack administrator
rabbitmq-plugins enable rabbitmq_management


