#!/usr/bin/env bash
# $1 sys_password

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

# Make sure that the configuration in conf.yml file is correct in terms of
# what network to use
apt-get install -qqy "$leap_aptopt" neutron-server

echo "Neutron packages are installed!"

tun_cidr=$(ip -4 addr show $leap_tunnelnic | awk -F '/' '/inet / {print $1}')
arr=($tun_cidr); my_ip="${arr[1]}"

service neutron-server stop

# Configre /etc/neutron/neutron.conf
echo "Configure the server component"

iniset /etc/neutron/neutron.conf DEFAULT core_plugin 'ml2'
iniset /etc/neutron/neutron.conf DEFAULT service_plugins 'router'
iniset /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips 'True'
iniset /etc/neutron/neutron.conf DEFAULT debug 'True'
iniset /etc/neutron/neutron.conf DEFAULT auth_strategy 'keystone'
iniset /etc/neutron/neutron.conf DEFAULT api_workers 3
iniset /etc/neutron/neutron.conf DEFAULT l3_ha True
iniset /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network 2

iniset /etc/neutron/neutron.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/neutron/neutron.conf DEFAULT notification_driver noop

iniset /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes 'True'
iniset /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes 'True'
iniset /etc/neutron/neutron.conf DEFAULT nova_url "http://${leap_logical2physical_nova}:8774/v2"

iniset /etc/neutron/neutron.conf database connection "mysql+pymysql://neutron:$1@${leap_logical2physical_mysqldb}/neutron"

iniset /etc/neutron/neutron.conf keystone_authtoken auth_uri "http://${leap_logical2physical_keystone}:5000"
iniset /etc/neutron/neutron.conf keystone_authtoken auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/neutron/neutron.conf keystone_authtoken auth_type 'password'
iniset /etc/neutron/neutron.conf keystone_authtoken project_domain_name 'default'
iniset /etc/neutron/neutron.conf keystone_authtoken user_domain_name 'default'
iniset /etc/neutron/neutron.conf keystone_authtoken project_name 'service'
iniset /etc/neutron/neutron.conf keystone_authtoken username 'neutron'
iniset /etc/neutron/neutron.conf keystone_authtoken password $1

inidelete /etc/neutron/neutron.conf keystone_authtoken identity_uri
inidelete /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name
inidelete /etc/neutron/neutron.conf keystone_authtoken admin_user
inidelete /etc/neutron/neutron.conf keystone_authtoken admin_password

iniset /etc/neutron/neutron.conf nova auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/neutron/neutron.conf nova auth_type 'password'
iniset /etc/neutron/neutron.conf nova project_domain_name 'default'
iniset /etc/neutron/neutron.conf nova user_domain_name 'default'
iniset /etc/neutron/neutron.conf nova region_name 'RegionOne'
iniset /etc/neutron/neutron.conf nova project_name 'service'
iniset /etc/neutron/neutron.conf nova username 'nova'
iniset /etc/neutron/neutron.conf nova password $1

# Configure /etc/neutron/plugins/ml2/ml2_conf.ini
echo "Configure Modular Layer 2 (ML2) plug-in"

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers 'flat,vxlan'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types 'vxlan'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers 'port_security'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers 'linuxbridge,l2population'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks 'public'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges '1:1000'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group '239.1.1.1'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan enable_vxlan 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan l2_population 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan local_ip $my_ip
iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan vxlan_group '239.1.1.1'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

iniset /etc/neutron/plugins/ml2/ml2_conf.ini linux_bridge physical_interface_mappings "vxlan:${leap_tunnelnic}"

# clean up configuration files

iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/plugins/ml2/ml2_conf.ini


su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

service neutron-server start

rm -f /var/lib/neutron/neutron.sqlite

echo "Neutron setup is now complete!"

