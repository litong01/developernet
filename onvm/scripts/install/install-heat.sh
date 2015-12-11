#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config

apt-get install -qqy heat-api heat-api-cfn heat-engine python-heatclient

echo "Heat packages are installed!"

iniset /etc/heat/heat.conf database connection "mysql+pymysql://heat:$1@mysqldb/heat"
iniset /etc/heat/heat.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/heat/heat.conf DEFAULT verbose 'True'
iniset /etc/heat/heat.conf DEFAULT auth_strategy 'keystone'

iniset /etc/heat/heat.conf DEFAULT heat_metadata_server_url 'http://heat:8000'
iniset /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url 'http://heat:8000/v1/waitcondition'

iniset /etc/heat/heat.conf DEFAULT stack_domain_admin 'heat_domain_admin'
iniset /etc/heat/heat.conf DEFAULT stack_domain_admin_password $1
iniset /etc/heat/heat.conf DEFAULT stack_user_domain_name 'heat'
iniset /etc/heat/heat.conf DEFAULT num_engine_workers 4

iniset /etc/heat/heat.conf oslo_messaging_rabbit rabbit_host rabbitmq
iniset /etc/heat/heat.conf oslo_messaging_rabbit rabbit_userid openstack
iniset /etc/heat/heat.conf oslo_messaging_rabbit rabbit_password $1

iniset /etc/heat/heat.conf keystone_authtoken auth_uri 'http://keystone:5000'
iniset /etc/heat/heat.conf keystone_authtoken auth_url 'http://keystone:35357'
iniset /etc/heat/heat.conf keystone_authtoken auth_plugin 'password'
iniset /etc/heat/heat.conf keystone_authtoken project_domain_id 'default'
iniset /etc/heat/heat.conf keystone_authtoken user_domain_id 'default'
iniset /etc/heat/heat.conf keystone_authtoken project_name 'service'
iniset /etc/heat/heat.conf keystone_authtoken username 'heat'
iniset /etc/heat/heat.conf keystone_authtoken password $1

iniset /etc/heat/heat.conf trustee auth_uri 'http://keystone:5000'
iniset /etc/heat/heat.conf trustee auth_url 'http://keystone:35357'
iniset /etc/heat/heat.conf trustee auth_plugin 'password'
iniset /etc/heat/heat.conf trustee project_domain_id 'default'
iniset /etc/heat/heat.conf trustee user_domain_id 'default'
iniset /etc/heat/heat.conf trustee project_name 'service'
iniset /etc/heat/heat.conf trustee username 'heat'
iniset /etc/heat/heat.conf trustee password $1

iniset /etc/heat/heat.conf clients_keystone auth_uri 'http://keystone:5000'
iniset /etc/heat/heat.conf ec2authtoken auth_uri 'http://keystone:5000'

iniremcomment /etc/heat/heat.conf

su -s /bin/sh -c "heat-manage db_sync" heat


service heat-api restart
service heat-api-cfn restart
service heat-engine restart

rm -f /var/lib/heat/heat.sqlite

echo 'Heat configuration is now complete!'

