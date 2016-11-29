#!/usr/bin/env bash
# $1 sys_password

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

apt-get install -qqy "$leap_aptopt" python-trove python-troveclient \
  python-glanceclient trove-common trove-api trove-taskmanager \
  trove-conductor

service trove-api stop
service trove-taskmanager stop
service trove-conductor stop

echo "Trove packages are installed!"

tun_cidr=$(ip -4 addr show $leap_tunnelnic | awk -F '/' '/inet / {print $1}')
arr=($tun_cidr); my_ip="${arr[1]}"

iniset /etc/trove/trove.conf DEFAULT debug 'True'
iniset /etc/trove/trove.conf DEFAULT auth_strategy 'keystone'
iniset /etc/trove/trove.conf DEFAULT my_ip $my_ip
iniset /etc/trove/trove.conf DEFAULT add_addresses True
iniset /etc/trove/trove.conf DEFAULT trove_auth_url "http://${leap_logical2physical_keystone}:5000/v2.0"
iniset /etc/trove/trove.conf DEFAULT nova_compute_url "http://${leap_logical2physical_nova}:8774/v2"
iniset /etc/trove/trove.conf DEFAULT network_label_regex '^NETWORK_LABEL$'
iniset /etc/trove/trove.conf DEFAULT api_paste_config /etc/trove/api-paste.ini

iniset /etc/trove/trove.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"

iniset /etc/trove/trove.conf database connection "mysql+pymysql://trove:$1@${leap_logical2physical_mysqldb}/trove"

iniset /etc/trove/trove.conf keystone_authtoken auth_uri "http://${leap_logical2physical_keystone}:5000"
iniset /etc/trove/trove.conf keystone_authtoken auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/trove/trove.conf keystone_authtoken auth_type 'password'
iniset /etc/trove/trove.conf keystone_authtoken project_domain_name 'Default'
iniset /etc/trove/trove.conf keystone_authtoken user_domain_name 'Default'
iniset /etc/trove/trove.conf keystone_authtoken project_name 'service'
iniset /etc/trove/trove.conf keystone_authtoken username 'trove'
iniset /etc/trove/trove.conf keystone_authtoken password $1

iniset /etc/trove/trove-taskmanager.conf DEFAULT debug True
iniset /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_user nova
iniset /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_pass $1
source ~/admin-openrc.sh
project_id=$(openstack project show service | grep '| id' | awk -F '|' '/id / {print $3}')
iniset /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_tenant_id $project_id

iniset /etc/trove/trove-taskmanager.conf DEFAULT taskmanager_manager 'trove.taskmanager.manager.Manager'
iniset /etc/trove/trove-taskmanager.conf DEFAULT trove_auth_url "http://${leap_logical2physical_keystone}:35357/v2.0"
iniset /etc/trove/trove-taskmanager.conf DEFAULT nova_compute_url "http://${leap_logical2physical_nova}:8774/v2"
iniset /etc/trove/trove-taskmanager.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"

iniset /etc/trove/trove-taskmanager.conf database connection "mysql+pymysql://trove:$1@${leap_logical2physical_mysqldb}/trove"

# Inject configuration into guest via ConfigDrive
iniset /etc/trove/trove-taskmanager.conf DEFAULT use_nova_server_config_drive True

# Set these if using Neutron Networking
iniset /etc/trove/trove-taskmanager.conf DEFAULT network_driver 'trove.network.neutron.NeutronDriver'
iniset /etc/trove/trove-taskmanager.conf DEFAULT network_label_regex '.*'

iniset /etc/trove/trove-taskmanager.conf keystone_authtoken auth_uri "http://${leap_logical2physical_keystone}:5000"
iniset /etc/trove/trove-taskmanager.conf keystone_authtoken auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/trove/trove-taskmanager.conf keystone_authtoken auth_type 'password'
iniset /etc/trove/trove-taskmanager.conf keystone_authtoken project_domain_name 'Default'
iniset /etc/trove/trove-taskmanager.conf keystone_authtoken user_domain_name 'Default'
iniset /etc/trove/trove-taskmanager.conf keystone_authtoken project_name 'service'
iniset /etc/trove/trove-taskmanager.conf keystone_authtoken username 'trove'
iniset /etc/trove/trove-taskmanager.conf keystone_authtoken password $1

iniset /etc/trove/trove-conductor.conf DEFAULT debug True
iniset /etc/trove/trove-conductor.conf DEFAULT trove_auth_url "http://${leap_logical2physical_keystone}:35357/v2.0"
iniset /etc/trove/trove-conductor.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/trove/trove-conductor.conf database connection "mysql+pymysql://trove:$1@${leap_logical2physical_mysqldb}/trove"


iniset /etc/trove/trove-guestagent.conf DEFAULT debug True
iniset /etc/trove/trove-guestagent.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_user nova
iniset /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_pass $1
iniset /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_tenant_id $project_id
iniset /etc/trove/trove-guestagent.conf DEFAULT trove_auth_url "http://${leap_logical2physical_keystone}:35357/v2.0"

iniremcomment /etc/trove/trove.conf
iniremcomment /etc/trove/trove-taskmanager.conf
iniremcomment /etc/trove/trove-conductor.conf
iniremcomment /etc/trove/trove-guestagent.conf

su -s /bin/sh -c "trove-manage db_sync" trove

rm -f /var/lib/trove/trove.sqlite
rm -f /var/log/trove/*.log

service trove-api start
service trove-taskmanager start
service trove-conductor start

echo 'Trove configuration is now complete!'

