#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

apt-get install -qqy "$leap_aptopt" glance python-glanceclient

echo "Glance packages are installed!"

iniset /etc/glance/glance-api.conf database connection "mysql+pymysql://glance:$1@${leap_logical2physical_mysqldb}/glance"
iniset /etc/glance/glance-api.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/glance/glance-api.conf DEFAULT debug 'True'
iniset /etc/glance/glance-api.conf DEFAULT notification_driver 'noop'

iniset /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_host "${leap_logical2physical_rabbitmq}"
iniset /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_userid openstack
iniset /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_password $1


iniset /etc/glance/glance-api.conf keystone_authtoken auth_uri "http://${leap_logical2physical_keystone}:5000"
iniset /etc/glance/glance-api.conf keystone_authtoken auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/glance/glance-api.conf keystone_authtoken auth_plugin 'password'
iniset /etc/glance/glance-api.conf keystone_authtoken project_domain_id 'default'
iniset /etc/glance/glance-api.conf keystone_authtoken user_domain_id 'default'
iniset /etc/glance/glance-api.conf keystone_authtoken project_name 'service'
iniset /etc/glance/glance-api.conf keystone_authtoken username 'glance'
iniset /etc/glance/glance-api.conf keystone_authtoken password $1

iniset /etc/glance/glance-api.conf 'paste_deploy' 'flavor' 'keystone'


mkdir -p $leap_glance_image_location
chown glance:glance $leap_glance_image_location


iniset /etc/glance/glance-api.conf 'glance_store' 'default_store' 'file'
iniset /etc/glance/glance-api.conf 'glance_store' 'filesystem_store_datadir' $leap_glance_image_location

iniset /etc/glance/glance-registry.conf database connection "mysql+pymysql://glance:$1@${leap_logical2physical_mysqldb}/glance"
iniset /etc/glance/glance-registry.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/glance/glance-registry.conf DEFAULT debug 'True'
iniset /etc/glance/glance-registry.conf DEFAULT notification_driver 'noop'

iniset /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_host "${leap_logical2physical_rabbitmq}"
iniset /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_userid 'openstack'
iniset /etc/glance/glance-registry.conf oslo_messaging_rabbit rabbit_password $1

iniset /etc/glance/glance-registry.conf keystone_authtoken auth_uri "http://${leap_logical2physical_keystone}:5000"
iniset /etc/glance/glance-registry.conf keystone_authtoken auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/glance/glance-registry.conf keystone_authtoken auth_plugin 'password'
iniset /etc/glance/glance-registry.conf keystone_authtoken project_domain_id 'default'
iniset /etc/glance/glance-registry.conf keystone_authtoken user_domain_id 'default'
iniset /etc/glance/glance-registry.conf keystone_authtoken project_name 'service'
iniset /etc/glance/glance-registry.conf keystone_authtoken username 'glance'
iniset /etc/glance/glance-registry.conf keystone_authtoken password $1

iniset /etc/glance/glance-registry.conf 'paste_deploy' 'flavor' 'keystone'

# Cleanup configuration files
iniremcomment /etc/glance/glance-api.conf 
iniremcomment /etc/glance/glance-registry.conf

su -s /bin/sh -c "glance-manage db_sync" glance

service glance-registry restart
service glance-api restart

rm -f /var/lib/glance/glance.sqlite

echo "Glance setup is now complete!"

