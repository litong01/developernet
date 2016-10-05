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
  neutron-lbaas-agent

echo "Neutron packages are installed!"

service neutron-server stop
service neutron-openvswitch-agent stop
service openvswitch-switch stop
service neutron-lbaas-agent stop


# Configre /etc/neutron/neutron.conf
echo "Configure the server component"

iniset /etc/neutron/neutron.conf database connection "mysql+pymysql://neutron:$1@${leap_logical2physical_mysqldb}/neutron"
iniset /etc/neutron/neutron.conf DEFAULT core_plugin 'ml2'
iniset /etc/neutron/neutron.conf DEFAULT service_plugins 'router,lbaas'
iniset /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips 'True'
iniset /etc/neutron/neutron.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/neutron/neutron.conf DEFAULT debug 'True'
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host "${leap_logical2physical_rabbitmq}"
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid 'openstack'
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $1
iniset /etc/neutron/neutron.conf DEFAULT auth_strategy 'keystone'
iniset /etc/neutron/neutron.conf DEFAULT l3_ha True
iniset /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network 1


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
echo "Configure Modular Layer 2 (ML2) plug-in"

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers 'flat,vxlan'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types 'vxlan'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers 'port_security'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks 'public'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges '1:1000'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group '239.1.1.1'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers "openvswitch,l2population"

iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip $3
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovs bridge_mappings 'public:br-ex'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovs integration_bridge br-int
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovs tunnel_bridge br-tun


# Configure the kernel to enable packet forwarding and disable reverse path filting
echo 'Configure the kernel to enable packet forwarding and disable reverse path filting'
confset /etc/sysctl.conf net.ipv4.ip_forward 1
confset /etc/sysctl.conf net.ipv4.conf.default.rp_filter 0
confset /etc/sysctl.conf net.ipv4.conf.all.rp_filter 0

echo 'Load the new kernel configuration'
sysctl -p

# Configuring load balancer
iniset /etc/neutron/neutron.conf service_providers service_provider 'LOADBALANCER:Haproxy:neutron_lbaas.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default'
iniset /etc/neutron/neutron_lbaas.conf service_providers service_provider 'LOADBALANCER:Haproxy:neutron_lbaas.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default'
iniset /etc/neutron/lbaas_agent.ini DEFAULT device_driver 'neutron_lbaas.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver'
iniset /etc/neutron/lbaas_agent.ini DEFAULT interface_driver 'neutron.agent.linux.interface.OVSInterfaceDriver'


# clean up configuration files

iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/plugins/ml2/ml2_conf.ini
iniremcomment /etc/neutron/neutron_lbaas.conf
iniremcomment /etc/neutron/lbaas_agent.ini

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron


#service openvswitch-switch start
service neutron-server start
service neutron-lbaas-agent start


rm -f /var/lib/neutron/neutron.sqlite

echo "Neutron setup is now complete!"

