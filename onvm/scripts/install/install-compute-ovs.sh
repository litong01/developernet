#!/usr/bin/env bash
# $1 sys_password

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get -qqy update

apt-get install -qqy "$leap_aptopt" nova-compute sysfsutils
apt-get install -qqy "$leap_aptopt" neutron-openvswitch-agent

# Get rid of virbr0
virsh net-destroy default
virsh net-undefine default


service nova-compute stop
service neutron-openvswitch-agent stop

echo "Compute packages are installed!"

tun_cidr=$(ip -4 addr show $leap_tunnelnic | awk -F '/' '/inet / {print $1}')
arr=($tun_cidr); my_ip="${arr[1]}"

iniset /etc/nova/nova.conf DEFAULT debug 'True'
iniset /etc/nova/nova.conf DEFAULT auth_strategy 'keystone'
iniset /etc/nova/nova.conf DEFAULT my_ip $my_ip
iniset /etc/nova/nova.conf DEFAULT enabled_apis 'osapi_compute,metadata'
iniset /etc/nova/nova.conf DEFAULT use_neutron True

iniset /etc/nova/nova.conf DEFAULT linuxnet_interface_driver 'nova.network.linux_net.LinuxOVSInterfaceDriver'
iniset /etc/nova/nova.conf DEFAULT firewall_driver 'nova.virt.firewall.NoopFirewallDriver'

metahost=$(echo '$leap_'$leap_logical2physical_nova'_'$leap_tunnelnic)
eval metahost=$metahost
iniset /etc/nova/nova.conf DEFAULT metadata_host $metahost
iniset /etc/nova/nova.conf DEFAULT instances_path $leap_instances_path

iniset /etc/nova/nova.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/nova/nova.conf DEFAULT notification_driver noop

iniset /etc/nova/nova.conf vnc vncserver_listen '0.0.0.0'
iniset /etc/nova/nova.conf vnc vncserver_proxyclient_address '$my_ip'
iniset /etc/nova/nova.conf vnc enabled 'True'

vnchost=$(echo '$leap_'$leap_logical2physical_nova'_'$leap_publicnic)
eval vnchost=$vnchost
iniset /etc/nova/nova.conf vnc novncproxy_base_url http://$vnchost:6080/vnc_auto.html

iniset /etc/nova/nova.conf glance api_servers http://$leap_logical2physical_glance:9292

iniset /etc/nova/nova.conf oslo_concurrency lock_path '/var/lib/nova/tmp'

iniset /etc/nova/nova.conf keystone_authtoken auth_uri http://$leap_logical2physical_keystone:5000
iniset /etc/nova/nova.conf keystone_authtoken auth_url http://$leap_logical2physical_keystone:35357
iniset /etc/nova/nova.conf keystone_authtoken auth_type 'password'
iniset /etc/nova/nova.conf keystone_authtoken project_domain_name 'default'
iniset /etc/nova/nova.conf keystone_authtoken user_domain_name 'default'
iniset /etc/nova/nova.conf keystone_authtoken project_name 'service'
iniset /etc/nova/nova.conf keystone_authtoken username 'nova'
iniset /etc/nova/nova.conf keystone_authtoken password $1


# Configure compute to use Networking
iniset /etc/nova/nova.conf neutron url http://$leap_logical2physical_neutron:9696
iniset /etc/nova/nova.conf neutron auth_uri http://$leap_logical2physical_keystone:5000
iniset /etc/nova/nova.conf neutron auth_url http://$leap_logical2physical_keystone:35357
iniset /etc/nova/nova.conf neutron auth_type 'password'
iniset /etc/nova/nova.conf neutron project_domain_name 'default'
iniset /etc/nova/nova.conf neutron user_domain_name 'default'
iniset /etc/nova/nova.conf neutron region_name 'RegionOne'
iniset /etc/nova/nova.conf neutron project_name 'service'
iniset /etc/nova/nova.conf neutron username 'neutron'
iniset /etc/nova/nova.conf neutron password $1
iniset /etc/nova/nova.conf neutron service_metadata_proxy 'True'
iniset /etc/nova/nova.conf neutron metadata_proxy_shared_secret $1
iniset /etc/nova/nova.conf neutron auth_strategy keystone


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

# Configure the kernel to enable packet forwarding and disable reverse path filting
echo 'Configure the kernel to enable packet forwarding and disable reverse path filting'
confset /etc/sysctl.conf net.ipv4.ip_forward 1
confset /etc/sysctl.conf net.ipv4.conf.default.rp_filter 0
confset /etc/sysctl.conf net.ipv4.conf.all.rp_filter 0
confset /etc/sysctl.conf net.bridge.bridge-nf-call-iptables 1
confset /etc/sysctl.conf net.bridge.bridge-nf-call-ip6tables 1

echo 'Load the new kernel configuration'
sysctl -p /etc/sysctl.conf

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

# Configure Modular Layer 2 agent /etc/neutron/plugins/ml2/openvswitch_agent.ini
echo "Configure openvswitch agent"

iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup enable_security_group 'True'
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup enable_ipset 'True'
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs local_ip $my_ip
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs enable_tunneling True
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs integration_bridge br-int
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini ovs tunnel_bridge br-tun

iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini agent tunnel_types vxlan
iniset /etc/neutron/plugins/ml2/openvswitch_agent.ini agent l2_population True

iniremcomment /etc/nova/nova.conf
iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/plugins/ml2/openvswitch_agent.ini

rm -f /var/lib/nova/nova.sqlite
rm -r -f /var/log/nova/* /var/log/neutron/*


echo "Start services..."
service nova-compute start
service neutron-openvswitch-agent start

echo "Compute setup is now complete!"
