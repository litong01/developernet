#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

# Make sure that the configuration in conf.yml file is correct in terms of
# what network to use
apt-get install -qqy "$leap_aptopt" neutron-server neutron-plugin-ml2 \
  neutron-linuxbridge-agent neutron-dhcp-agent haproxy neutron-lbaas-agent \
  python-neutronclient

echo "Neutron packages are installed!"

service neutron-server stop
service neutron-linuxbridge-agent stop
service neutron-dhcp-agent stop
service neutron-metadata-agent stop
service neutron-lbaas-agent stop


# Configre /etc/neutron/neutron.conf
echo "Configure the server component"

iniset /etc/neutron/neutron.conf database connection "mysql+pymysql://neutron:$1@${leap_logical2physical_mysqldb}/neutron"
iniset /etc/neutron/neutron.conf DEFAULT core_plugin 'ml2'
iniset /etc/neutron/neutron.conf DEFAULT service_plugins 'router,lbaas'
iniset /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips 'True'
iniset /etc/neutron/neutron.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/neutron/neutron.conf DEFAULT debug 'True'
iniset /etc/neutron/neutron.conf DEFAULT auth_strategy 'keystone'
iniset /etc/neutron/neutron.conf DEFAULT l3_ha True
iniset /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network 1

iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host "${leap_logical2physical_rabbitmq}"
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid 'openstack'
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $1


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

iniset /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes 'True'
iniset /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes 'True'
iniset /etc/neutron/neutron.conf DEFAULT nova_url "http://${leap_logical2physical_nova}:8774/v2"

iniset /etc/neutron/neutron.conf nova auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/neutron/neutron.conf nova auth_type 'password'
iniset /etc/neutron/neutron.conf nova project_domain_name 'default'
iniset /etc/neutron/neutron.conf nova user_domain_name 'default'
iniset /etc/neutron/neutron.conf nova region_name 'RegionOne'
iniset /etc/neutron/neutron.conf nova project_name 'service'
iniset /etc/neutron/neutron.conf nova username 'nova'
iniset /etc/neutron/neutron.conf nova password $1

# Configure /etc/neutron/plugins/ml2/ml2_conf.ini
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers 'flat,vxlan'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types 'vxlan'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers 'port_security'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers 'linuxbridge'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks 'public'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges '1:1000'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group '239.1.1.1'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

iniset /etc/neutron/plugins/ml2/ml2_conf.ini linux_bridge physical_interface_mappings "vxlan:eth1"

iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan enable_vxlan 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan l2_population 'False'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan local_ip $3
iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan vxlan_group '239.1.1.1'


echo "Configure linuxbridge agent"

iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2 type_drivers 'flat,vxlan'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2 tenant_network_types 'vxlan'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2 extension_drivers 'port_security'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2 mechanism_drivers 'linuxbridge'

iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2_type_flat flat_networks 'public'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2_type_vxlan vni_ranges '1:1000'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2_type_vxlan vxlan_group '239.1.1.1'

iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_ipset 'True'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings "vxlan:eth1"

iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan 'True'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population 'False'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip $3
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan vxlan_group '239.1.1.1'


# Configure /etc/neutron/dhcp_agent.ini 
echo "Configure the dhcp agent"

iniset /etc/neutron/dhcp_agent.ini DEFAULT interface_driver 'neutron.agent.linux.interface.BridgeInterfaceDriver'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver 'neutron.agent.linux.dhcp.Dnsmasq'
iniset /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
iniset /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces ' True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces 'True'
#iniset /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file '/etc/neutron/dnsmasq-neutron.conf'

#echo 'dhcp-option-force=26,1454' > /etc/neutron/dnsmasq-neutron.conf

# Configuring load balancer
iniset /etc/neutron/neutron.conf service_providers service_provider 'LOADBALANCER:Haproxy:neutron_lbaas.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default'
iniset /etc/neutron/neutron_lbaas.conf service_providers service_provider 'LOADBALANCER:Haproxy:neutron_lbaas.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default'
iniset /etc/neutron/lbaas_agent.ini DEFAULT device_driver 'neutron_lbaas.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver'
iniset /etc/neutron/lbaas_agent.ini DEFAULT interface_driver 'neutron.agent.linux.interface.BridgeInterfaceDriver'


# clean up configuration files

iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/plugins/ml2/ml2_conf.ini
iniremcomment /etc/neutron/plugins/ml2/linuxbridge_agent.ini
iniremcomment /etc/neutron/dhcp_agent.ini
iniremcomment /etc/neutron/neutron_lbaas.conf
iniremcomment /etc/neutron/lbaas_agent.ini


su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

neutron-db-manage --service lbaas upgrade head

service neutron-server start
service neutron-linuxbridge-agent start
service neutron-dhcp-agent start
service neutron-lbaas-agent start

rm -f /var/lib/neutron/neutron.sqlite

echo "Neutron setup is now complete!"

