#!/usr/bin/env bash
# $1 sys_password

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get -qqy update

apt-get install -qqy "$leap_aptopt" neutron-openvswitch-agent \
  neutron-l3-agent neutron-dhcp-agent haproxy

service neutron-metadata-agent stop
service neutron-l3-agent stop
service neutron-dhcp-agent stop
service neutron-openvswitch-agent stop

echo "Network node packages are installed!"

tun_cidr=$(ip -4 addr show $leap_tunnelnic | awk -F '/' '/inet / {print $1}')
arr=($tun_cidr); my_ip="${arr[1]}"

# Configure the kernel to enable packet forwarding and disable reverse path filting
echo 'Configure the kernel to enable packet forwarding and disable reverse path filting'
confset /etc/sysctl.conf net.ipv4.ip_forward 1
confset /etc/sysctl.conf net.ipv4.conf.default.rp_filter 0
confset /etc/sysctl.conf net.ipv4.conf.all.rp_filter 0
confset /etc/sysctl.conf net.bridge.bridge-nf-call-iptables 1
confset /etc/sysctl.conf net.bridge.bridge-nf-call-ip6tables 1

echo 'Load the new kernel configuration'
sysctl -p /etc/sysctl.conf

# Configure neutron on compute node /etc/neutron/neutron.conf
echo 'Configure neutron network node node'

iniset /etc/neutron/neutron.conf DEFAULT auth_strategy 'keystone'
iniset /etc/neutron/neutron.conf DEFAULT debug 'True'
iniset /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips 'True'

iniset /etc/neutron/neutron.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/neutron/neutron.conf DEFAULT notification_driver noop

iniset /etc/neutron/neutron.conf keystone_authtoken auth_uri "http://${leap_logical2physical_keystone}:5000"
iniset /etc/neutron/neutron.conf keystone_authtoken auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/neutron/neutron.conf keystone_authtoken auth_type 'password'
iniset /etc/neutron/neutron.conf keystone_authtoken project_domain_name 'Default'
iniset /etc/neutron/neutron.conf keystone_authtoken user_domain_name 'Default'
iniset /etc/neutron/neutron.conf keystone_authtoken project_name 'service'
iniset /etc/neutron/neutron.conf keystone_authtoken username 'neutron'
iniset /etc/neutron/neutron.conf keystone_authtoken password $1

inidelete /etc/neutron/neutron.conf keystone_authtoken identity_uri
inidelete /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name
inidelete /etc/neutron/neutron.conf keystone_authtoken admin_user
inidelete /etc/neutron/neutron.conf keystone_authtoken admin_password

# Configure Modular Layer 2 agent /etc/neutron/plugins/ml2/openvswitch_agent.ini
echo "Configure openvswitch agent"

iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup enable_security_group 'True'
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup enable_ipset 'True'
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip $my_ip
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs enable_tunneling True
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs bridge_mappings 'public:br-ex'
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs integration_bridge br-int
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs tunnel_bridge br-tun

iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True

# Configure /etc/neutron/l3_agent.ini 
echo "Configure the layer-3 agent"

iniset /etc/neutron/l3_agent.ini DEFAULT interface_driver 'neutron.agent.linux.interface.OVSInterfaceDriver'
iniset /etc/neutron/l3_agent.ini DEFAULT external_network_bridge 'br-ex'
iniset /etc/neutron/l3_agent.ini DEFAULT debug 'True'
iniset /etc/neutron/l3_agent.ini DEFAULT verbose 'True'
iniset /etc/neutron/l3_agent.ini DEFAULT use_namespaces 'True'
iniset /etc/neutron/l3_agent.ini DEFAULT router_delete_namespaces 'True'

#Configure /etc/neutron/metadata_agent.ini
echo "Configure the metadata agent"

metahost=$(echo '$leap_'$leap_logical2physical_nova'_'$leap_tunnelnic)
eval metahost=$metahost
iniset /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $metahost
iniset /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $1

inidelete /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name
inidelete /etc/neutron/metadata_agent.ini DEFAULT admin_user
inidelete /etc/neutron/metadata_agent.ini DEFAULT admin_password

# Configure /etc/neutron/dhcp_agent.ini
echo "Configure the DHCP agent"

iniset /etc/neutron/dhcp_agent.ini DEFAULT interface_driver 'neutron.agent.linux.interface.OVSInterfaceDriver'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver 'neutron.agent.linux.dhcp.Dnsmasq'
iniset /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata 'True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces ' True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces 'True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file '/etc/neutron/dnsmasq-neutron.conf'

echo 'dhcp-option-force=26,1454' > /etc/neutron/dnsmasq-neutron.conf

iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/dhcp_agent.ini
iniremcomment /etc/neutron/l3_agent.ini
iniremcomment /etc/neutron/metadata_agent.ini
iniremcomment /etc/neutron/plugins/ml2/openvswitch_agent.ini

echo 'Adding br-ex bridge...'
ovs-vsctl --may-exist add-br br-ex

echo "Start services..."
service neutron-openvswitch-agent start
service neutron-l3-agent start
service neutron-dhcp-agent start
service neutron-metadata-agent start

#echo "Configuring bridges"

echo "Adding public nic to ovs bridge..."
br_ex_ip=$(ip -4 addr show $leap_publicnic | awk '/inet / {print $2}')
default_gw=$(route -n | awk '/^0.0.0.0 /{print $2}')

echo 'Process interfaces file to make changes permanent...'
pos=$(sed -n "/^auto $leap_publicnic/,/^auto/=" /etc/network/interfaces)
pos=$(echo $pos); read -r -a pos <<< "$pos"
netmask=$(ifconfig "$leap_publicnic" | awk -F ':' '/inet / {print $4}')
sed -i "${pos[0]},${pos[-2]}d" /etc/network/interfaces

echo "" >> /etc/network/interfaces
echo "auto br-ex" >> /etc/network/interfaces
echo "allow-ovs br-ex" >> /etc/network/interfaces
echo "iface br-ex inet static" >> /etc/network/interfaces
echo "  ovs_type OVSBridge" >> /etc/network/interfaces
echo "  ovs_ports $leap_publicnic" >> /etc/network/interfaces
echo "  address $br_ex_ip" >> /etc/network/interfaces
echo "  netmask $netmask" >> /etc/network/interfaces
echo "  gateway $default_gw" >> /etc/network/interfaces
echo "  dns-nameservers 8.8.8.8 8.8.4.4" >> /etc/network/interfaces

echo "" >> /etc/network/interfaces
echo "auto $leap_publicnic" >> /etc/network/interfaces
echo "allow-br-ex $leap_publicnic" >> /etc/network/interfaces
echo "iface $leap_publicnic inet manual" >> /etc/network/interfaces
echo "  ovs_type OVSPort" >> /etc/network/interfaces
echo "  ovs_bridge br-ex" >> /etc/network/interfaces

ip addr del $br_ex_ip dev $leap_publicnic; ip addr add $br_ex_ip brd + dev br-ex; ovs-vsctl add-port br-ex $leap_publicnic; ip link set dev br-ex up; ip route add default via $default_gw dev br-ex

echo "Neutron network setup is now complete!"
