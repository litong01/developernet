#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get -qqy update

apt-get install -qqy "$leap_aptopt" neutron-plugin-linuxbridge-agent \
  neutron-l3-agent neutron-dhcp-agent haproxy

service neutron-metadata-agent stop
service neutron-l3-agent stop
service neutron-dhcp-agent stop
service neutron-linuxbridge-agent stop

echo "Network node packages are installed!"

iniset /etc/neutron/neutron.conf DEFAULT auth_strategy 'keystone'
iniset /etc/neutron/neutron.conf DEFAULT debug 'True'
iniset /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips 'True'

iniset /etc/neutron/neutron.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/neutron/neutron.conf DEFAULT notification_driver noop

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

# Configure the OVS agent /etc/neutron/plugins/ml2/linuxbridge_agent.ini

echo "Configure Modular Layer 2 (ML2) plug-in"

iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2_type_flat flat_networks 'public'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2_type_vxlan vni_ranges '1:1000'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini ml2_type_vxlan vxlan_group '239.1.1.1'

iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_ipset 'True'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings "public:${leap_pubnic},vxlan:eth1"

iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan 'True'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population 'True'
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip $3
iniset /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan vxlan_group '239.1.1.1'

# Configure the kernel to enable packet forwarding and disable reverse path filting
echo 'Configure the kernel to enable packet forwarding and disable reverse path filting'
confset /etc/sysctl.conf net.ipv4.ip_forward 1
confset /etc/sysctl.conf net.ipv4.conf.default.rp_filter 0
confset /etc/sysctl.conf net.ipv4.conf.all.rp_filter 0

echo 'Load the new kernel configuration'
sysctl -p

# Configure /etc/neutron/l3_agent.ini 
echo "Configure the layer-3 agent"

iniset /etc/neutron/l3_agent.ini DEFAULT interface_driver 'neutron.agent.linux.interface.BridgeInterfaceDriver'
iniset /etc/neutron/l3_agent.ini DEFAULT external_network_bridge ''
iniset /etc/neutron/l3_agent.ini DEFAULT debug 'True'
iniset /etc/neutron/l3_agent.ini DEFAULT verbose 'True'
iniset /etc/neutron/l3_agent.ini DEFAULT use_namespaces 'True'
iniset /etc/neutron/l3_agent.ini DEFAULT router_delete_namespaces 'True'

#Configure /etc/neutron/metadata_agent.ini
echo "Configure the metadata agent"

metahost=$(echo '$leap_'$leap_logical2physical_nova'_eth1')
eval metahost=$metahost
iniset /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $metahost
iniset /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $1

inidelete /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name
inidelete /etc/neutron/metadata_agent.ini DEFAULT admin_user
inidelete /etc/neutron/metadata_agent.ini DEFAULT admin_password


# Configure /etc/neutron/dhcp_agent.ini 
echo "Configure the dhcp agent"

iniset /etc/neutron/dhcp_agent.ini DEFAULT interface_driver 'neutron.agent.linux.interface.BridgeInterfaceDriver'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver 'neutron.agent.linux.dhcp.Dnsmasq'
iniset /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata True
iniset /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces ' True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces 'True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file '/etc/neutron/dnsmasq-neutron.conf'

echo 'dhcp-option-force=26,1454' > /etc/neutron/dnsmasq-neutron.conf

iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/l3_agent.ini
iniremcomment /etc/neutron/metadata_agent.ini
iniremcomment /etc/neutron/dhcp_agent.ini
iniremcomment /etc/neutron/plugins/ml2/linuxbridge_agent.ini

rm -f /var/lib/nova/nova.sqlite
rm -r -f /var/log/nova/* /var/log/neutron/*

service neutron-linuxbridge-agent start
service neutron-metadata-agent start
service neutron-l3-agent start
service neutron-dhcp-agent start

echo "Compute setup is now complete!"
