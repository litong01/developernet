#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

apt-get install -qqy "$leap_aptopt" nova-api nova-cert nova-conductor nova-consoleauth \
  nova-novncproxy nova-scheduler python-novaclient

echo "Nova packages are installed!"

iniset /etc/nova/nova.conf database connection mysql+pymysql://nova:$1@$leap_logical2physical_mysqldb/nova
iniset /etc/nova/nova.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/nova/nova.conf DEFAULT debug 'True'
iniset /etc/nova/nova.conf DEFAULT auth_strategy 'keystone'
iniset /etc/nova/nova.conf DEFAULT my_ip "$2"
iniset /etc/nova/nova.conf DEFAULT enabled_apis 'osapi_compute,metadata'
iniset /etc/nova/nova.conf DEFAULT notification_driver messagingv2
iniset /etc/nova/nova.conf DEFAULT notification_topics notifications

iniset /etc/nova/nova.conf DEFAULT network_api_class 'nova.network.neutronv2.api.API'
iniset /etc/nova/nova.conf DEFAULT security_group_api 'neutron'
iniset /etc/nova/nova.conf DEFAULT linuxnet_interface_driver 'nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver'
iniset /etc/nova/nova.conf DEFAULT firewall_driver 'nova.virt.firewall.NoopFirewallDriver'

iniset /etc/nova/nova.conf vnc vncserver_listen '$my_ip'
iniset /etc/nova/nova.conf vnc vncserver_proxyclient_address '$my_ip'

iniset /etc/nova/nova.conf glance host $leap_logical2physical_glance

iniset /etc/nova/nova.conf oslo_concurrency lock_path '/var/lib/nova/tmp'

iniset /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host $leap_logical2physical_rabbitmq
iniset /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack
iniset /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password $1


iniset /etc/nova/nova.conf keystone_authtoken auth_uri http://$leap_logical2physical_keystone:5000
iniset /etc/nova/nova.conf keystone_authtoken auth_url http://$leap_logical2physical_keystone:35357
iniset /etc/nova/nova.conf keystone_authtoken auth_plugin 'password'
iniset /etc/nova/nova.conf keystone_authtoken project_domain_id 'default'
iniset /etc/nova/nova.conf keystone_authtoken user_domain_id 'default'
iniset /etc/nova/nova.conf keystone_authtoken project_name 'service'
iniset /etc/nova/nova.conf keystone_authtoken username 'nova'
iniset /etc/nova/nova.conf keystone_authtoken password $1

iniset /etc/nova/nova.conf neutron url http://$leap_logical2physical_neutron:9696
iniset /etc/nova/nova.conf neutron auth_url http://$leap_logical2physical_keystone:35357
iniset /etc/nova/nova.conf neutron auth_plugin 'password'
iniset /etc/nova/nova.conf neutron project_domain_id 'default'
iniset /etc/nova/nova.conf neutron user_domain_id 'default'
iniset /etc/nova/nova.conf neutron region_name 'RegionOne'
iniset /etc/nova/nova.conf neutron project_name 'service'
iniset /etc/nova/nova.conf neutron username 'neutron'
iniset /etc/nova/nova.conf neutron password $1
iniset /etc/nova/nova.conf neutron service_metadata_proxy 'True'
iniset /etc/nova/nova.conf neutron metadata_proxy_shared_secret $1

#Setup cadf


iniset /etc/nova/api-paste.ini 'composite:openstack_compute_api_legacy_v2' 'keystone' 'compute_req_id faultwrap sizelimit authtoken audit keystonecontext legacy_ratelimit osapi_compute_app_legacy_v2'
iniset /etc/nova/api-paste.ini 'composite:openstack_compute_api_legacy_v2' 'keystone_nolimit' 'compute_req_id faultwrap sizelimit authtoken audit keystonecontext osapi_compute_app_legacy_v2'

iniset /etc/nova/api-paste.ini 'composite:openstack_compute_api_v21' keystone 'compute_req_id faultwrap sizelimit authtoken audit keystonecontext osapi_compute_app_v21'
iniset /etc/nova/api-paste.ini 'composite:openstack_compute_api_v21_legacy_v2_compatible' keystone 'compute_req_id faultwrap sizelimit authtoken audit keystonecontext legacy_v2_compatible osapi_compute_app_v21'
iniset /etc/nova/api-paste.ini 'filter:audit' 'paste.filter_factory' 'keystonemiddleware.audit:filter_factory'
iniset /etc/nova/api-paste.ini 'filter:audit' 'audit_map_file' '/etc/nova/api_audit_map.conf'

iniremcomment /etc/nova/nova.conf
iniremcomment /etc/nova/api-paste.ini
wget https://raw.githubusercontent.com/openstack/pycadf/stable/liberty/etc/pycadf/nova_api_audit_map.conf -O /etc/nova/api_audit_map.conf
chown nova:nova /etc/nova/api_audit_map.conf

su -s /bin/sh -c "nova-manage db sync" nova

service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

rm -f /var/lib/nova/nova.sqlite

mkdir -p /storage
sp=$(lvdisplay | grep /dev/vg02/storage)
if [ ! "$sp" ];then
  echo 'Ready to create storage'
  lvcreate -l 100%FREE -n storage vg02
  mkfs -t ext4 /dev/vg02/storage
fi

sp=$(mount | grep /storage)
if [ ! "$sp" ]; then
  mount /dev/vg02/storage /storage/
  echo '/dev/mapper/vg02-storage    /storage    ext4    errors=continue    0    0' >> /etc/fstab
fi


echo "Nova setup is now complete!"
