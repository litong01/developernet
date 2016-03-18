#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

apt-get -qqy update
apt-get install -qqy "$leap_aptopt" nova-compute sysfsutils
apt-get install -qqy "$leap_aptopt" neutron-plugin-linuxbridge-agent

echo "Compute packages are installed!"

iniset /etc/nova/nova.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/nova/nova.conf DEFAULT debug 'True'
iniset /etc/nova/nova.conf DEFAULT auth_strategy 'keystone'
iniset /etc/nova/nova.conf DEFAULT my_ip $3
iniset /etc/nova/nova.conf DEFAULT enabled_apis 'osapi_compute,metadata'

iniset /etc/nova/nova.conf DEFAULT network_api_class 'nova.network.neutronv2.api.API'
iniset /etc/nova/nova.conf DEFAULT security_group_api 'neutron'
iniset /etc/nova/nova.conf DEFAULT linuxnet_interface_driver 'nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver'
iniset /etc/nova/nova.conf DEFAULT firewall_driver 'nova.virt.firewall.NoopFirewallDriver'

metahost=$(echo '$leap_'$leap_logical2physical_nova'_eth1')
eval metahost=$metahost
iniset /etc/nova/nova.conf DEFAULT metadata_host $metahost

iniset /etc/nova/nova.conf vnc vncserver_listen '0.0.0.0'
iniset /etc/nova/nova.conf vnc vncserver_proxyclient_address '$my_ip'
iniset /etc/nova/nova.conf vnc enabled 'True'

vnchost=$(echo '$leap_'$leap_logical2physical_nova'_eth0')
eval vnchost=$vnchost
iniset /etc/nova/nova.conf vnc novncproxy_base_url http://$vnchost:6080/vnc_auto.html

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


# Configure compute to use Networking
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


# Configure nova to use cinder
iniset /etc/nova/nova.conf cinder os_region_name  'RegionOne'

# if we have to use qemu
doqemu=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ $doqemu -eq 0 ]; then
  iniset /etc/nova/nova.conf libvirt virt_type 'qemu'
  iniset /etc/nova/nova-compute.conf libvirt virt_type 'qemu'
fi

# Configure neutron on compute node /etc/neutron/neutron.conf
echo 'Configure neutron on compute node'


confset /etc/sysctl.conf net.ipv4.conf.default.rp_filter 0
confset /etc/sysctl.conf net.ipv4.conf.all.rp_filter 0
confset /etc/sysctl.conf net.bridge.bridge-nf-call-iptables 1
confset /etc/sysctl.conf net.bridge.bridge-nf-call-ip6tables 1
#confset /etc/sysctl.conf net.ipv4.ip_forward 1

sysctl -p

iniset /etc/neutron/neutron.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/neutron/neutron.conf DEFAULT auth_strategy 'keystone'
iniset /etc/neutron/neutron.conf DEFAULT debug 'True'
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host $leap_logical2physical_rabbitmq
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid 'openstack'
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $1

iniset /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$leap_logical2physical_keystone:5000
iniset /etc/neutron/neutron.conf keystone_authtoken auth_url http://$leap_logical2physical_keystone:35357
iniset /etc/neutron/neutron.conf keystone_authtoken auth_plugin 'password'
iniset /etc/neutron/neutron.conf keystone_authtoken project_domain_id 'default'
iniset /etc/neutron/neutron.conf keystone_authtoken user_domain_id 'default'
iniset /etc/neutron/neutron.conf keystone_authtoken project_name 'service'
iniset /etc/neutron/neutron.conf keystone_authtoken username 'neutron'
iniset /etc/neutron/neutron.conf keystone_authtoken password $1

inidelete /etc/neutron/neutron.conf keystone_authtoken identity_uri
inidelete /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name
inidelete /etc/neutron/neutron.conf keystone_authtoken admin_user
inidelete /etc/neutron/neutron.conf keystone_authtoken admin_password


# Configure the OVS agent /etc/neutron/plugins/ml2/ml2_conf.ini
echo "Configure the OVS agent!"

echo "Configure Modular Layer 2 (ML2) plug-in"

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers 'flat,vxlan'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types 'vxlan'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers "linuxbridge,l2population"
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers 'port_security'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks 'public'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vni_ranges '1001:2000'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vxlan vxlan_group '239.1.1.1'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset 'True'

echo "Configure linuxbridge agent"

iniset /etc/neutron/plugins/ml2/ml2_conf.ini linux_bridge physical_interface_mappings 'vxlan:eth1'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan enable_vxlan 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini vxlan local_ip $3
iniset /etc/neutron/plugins/ml2/ml2_conf.ini agent prevent_arp_spoofing 'True'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types vxlan
iniset /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver 'neutron.agent.linux.iptables_firewall.IptablesFirewallDriver'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini agent l2_population True
iniset /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types vxlan


# Configure the kernel to enable packet forwarding and disable reverse path filting
echo 'Configure the kernel to enable packet forwarding and disable reverse path filting'
confset /etc/sysctl.conf net.ipv4.ip_forward 1
confset /etc/sysctl.conf net.ipv4.conf.default.rp_filter 0
confset /etc/sysctl.conf net.ipv4.conf.all.rp_filter 0

echo 'Load the new kernel configuration'
sysctl -p


iniremcomment /etc/nova/nova.conf
iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/plugins/ml2/ml2_conf.ini


rm -f /var/lib/nova/nova.sqlite

service nova-compute restart

service neutron-plugin-linuxbridge-agent restart

echo "Compute setup is now complete!"
