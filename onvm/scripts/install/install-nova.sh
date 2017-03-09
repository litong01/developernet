#!/usr/bin/env bash
# $1 sys_password

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

apt-get install -qqy "$leap_aptopt" nova-api nova-cert nova-conductor nova-consoleauth \
  nova-novncproxy nova-scheduler python-novaclient

echo "Nova packages are installed!"

service nova-api stop
service nova-cert stop
service nova-consoleauth stop
service nova-scheduler stop
service nova-conductor stop
service nova-novncproxy stop


pub_cidr=$(ip -4 addr show $leap_publicnic | awk -F '/' '/inet / {print $1}')
arr=($pub_cidr); pub_ip="${arr[1]}"

iniset /etc/nova/nova.conf DEFAULT debug 'True'
iniset /etc/nova/nova.conf DEFAULT auth_strategy 'keystone'
iniset /etc/nova/nova.conf DEFAULT my_ip "$pub_ip"
iniset /etc/nova/nova.conf DEFAULT enabled_apis 'osapi_compute,metadata'
iniset /etc/nova/nova.conf DEFAULT use_neutron True
iniset /etc/nova/nova.conf DEFAULT firewall_driver 'nova.virt.firewall.NoopFirewallDriver'
iniset /etc/nova/nova.conf DEFAULT instances_path $leap_instances_path
iniset /etc/nova/nova.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/nova/nova.conf DEFAULT notification_driver noop
iniset /etc/nova/nova.conf DEFAULT dhcp_domain ""

inidelete /etc/nova/nova.conf DEFAULT ec2_private_dns_show_ip

iniset /etc/nova/nova.conf api_database connection mysql+pymysql://nova:$1@$leap_logical2physical_mysqldb/nova_api
iniset /etc/nova/nova.conf database connection mysql+pymysql://nova:$1@$leap_logical2physical_mysqldb/nova

iniset /etc/nova/nova.conf vnc vncserver_listen '$my_ip'
iniset /etc/nova/nova.conf vnc vncserver_proxyclient_address '$my_ip'

iniset /etc/nova/nova.conf glance api_servers http://$leap_logical2physical_glance:9292

iniset /etc/nova/nova.conf oslo_concurrency lock_path '/var/lib/nova/tmp'

iniset /etc/nova/nova.conf keystone_authtoken auth_uri http://$leap_logical2physical_keystone:5000
iniset /etc/nova/nova.conf keystone_authtoken auth_url http://$leap_logical2physical_keystone:35357
iniset /etc/nova/nova.conf keystone_authtoken auth_type 'password'
iniset /etc/nova/nova.conf keystone_authtoken project_domain_name 'Default'
iniset /etc/nova/nova.conf keystone_authtoken user_domain_name 'Default'
iniset /etc/nova/nova.conf keystone_authtoken project_name 'service'
iniset /etc/nova/nova.conf keystone_authtoken username 'nova'
iniset /etc/nova/nova.conf keystone_authtoken password $1

iniset /etc/nova/nova.conf neutron url http://$leap_logical2physical_neutron:9696
iniset /etc/nova/nova.conf neutron auth_uri http://$leap_logical2physical_keystone:5000
iniset /etc/nova/nova.conf neutron auth_url http://$leap_logical2physical_keystone:35357
iniset /etc/nova/nova.conf neutron auth_type 'password'
iniset /etc/nova/nova.conf neutron project_domain_name 'Default'
iniset /etc/nova/nova.conf neutron user_domain_name 'Default'
iniset /etc/nova/nova.conf neutron region_name 'RegionOne'
iniset /etc/nova/nova.conf neutron project_name 'service'
iniset /etc/nova/nova.conf neutron username 'neutron'
iniset /etc/nova/nova.conf neutron password $1
iniset /etc/nova/nova.conf neutron service_metadata_proxy 'True'
iniset /etc/nova/nova.conf neutron metadata_proxy_shared_secret $1
iniset /etc/nova/nova.conf neutron auth_strategy keystone

iniremcomment /etc/nova/nova.conf
iniremcomment /etc/nova/api-paste.ini


su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova

service nova-api start
service nova-cert start
service nova-consoleauth start
service nova-scheduler start
service nova-conductor start
service nova-novncproxy start

rm -f /var/lib/nova/nova.sqlite

echo "Nova setup is now complete!"
