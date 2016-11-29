#!/usr/bin/env bash
# $1 sys_password

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

apt-get install -qqy "$leap_aptopt" nova-compute sysfsutils

# Get rid of virbr0
virsh net-destroy default
virsh net-undefine default

service nova-compute stop
echo "Nova Compute packages are installed!"

tun_cidr=$(ip -4 addr show $leap_tunnelnic | awk -F '/' '/inet / {print $1}')
arr=($tun_cidr); my_ip="${arr[1]}"

iniset /etc/nova/nova.conf DEFAULT debug 'True'
iniset /etc/nova/nova.conf DEFAULT auth_strategy 'keystone'
iniset /etc/nova/nova.conf DEFAULT my_ip $my_ip
iniset /etc/nova/nova.conf DEFAULT enabled_apis 'osapi_compute,metadata'
iniset /etc/nova/nova.conf DEFAULT force_config_drive True
iniset /etc/nova/nova.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/nova/nova.conf DEFAULT notification_driver noop
iniset /etc/nova/nova.conf DEFAULT network_api_class 'nova.network.neutronv2.api.API'
iniset /etc/nova/nova.conf DEFAULT use_neutron 'True'
iniset /etc/nova/nova.conf DEFAULT firewall_driver 'nova.virt.firewall.NoopFirewallDriver'

metahost=$(echo '$leap_'$leap_logical2physical_nova'_'$leap_tunnelnic)
eval metahost=$metahost
iniset /etc/nova/nova.conf DEFAULT metadata_host $metahost
iniset /etc/nova/nova.conf DEFAULT instances_path $leap_instances_path

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
iniset /etc/nova/nova.conf keystone_authtoken project_domain_name 'Default'
iniset /etc/nova/nova.conf keystone_authtoken user_domain_name 'Default'
iniset /etc/nova/nova.conf keystone_authtoken project_name 'service'
iniset /etc/nova/nova.conf keystone_authtoken username 'nova'
iniset /etc/nova/nova.conf keystone_authtoken password $1


# Configure compute to use Networking
iniset /etc/nova/nova.conf neutron url http://$leap_logical2physical_neutron:9696
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


# Configure nova to use cinder
iniset /etc/nova/nova.conf cinder os_region_name  'RegionOne'

# if we have to use qemu
doqemu=$(egrep -c '(vmx|svm)' /proc/cpuinfo)
if [ $doqemu -eq 0 ]; then
  iniset /etc/nova/nova.conf libvirt virt_type 'qemu'
  iniset /etc/nova/nova-compute.conf libvirt virt_type 'qemu'
fi

# Remove some of the default settings
inidelete /etc/nova/nova.conf DEFAULT libvirt_use_virtio_for_bridges
inidelete /etc/nova/nova.conf DEFAULT dhcpbridge
inidelete /etc/nova/nova.conf DEFAULT dhcpbridge_flagfile


echo 'Installing OVN..'

apt-get install -qqy dkms openvswitch-common openvswitch-switch ovn-common \
  python-openvswitch ovn-host

neutronhost=$(echo '$leap_'$leap_logical2physical_neutron'_'$leap_tunnelnic)
eval neutronhost=$neutronhost


echo "export OVN_NB_DB=tcp:$neutronhost:6641" >> ~/.bash_profile
echo "export OVN_SB_DB=tcp:$neutronhost:6642" >> ~/.bash_profile
export OVN_NB_DB=tcp:$neutronhost:6641
export OVN_SB_DB=tcp:$neutronhost:6642

ovs-vsctl --no-wait set open_vswitch . external-ids:ovn-remote=tcp:$neutronhost:6642
ovs-vsctl --no-wait set open_vswitch . external-ids:ovn-bridge="br-int"
ovs-vsctl --no-wait set open_vswitch . external-ids:ovn-encap-type="geneve"
ovs-vsctl --no-wait set open_vswitch . external-ids:ovn-encap-ip=$my_ip

ovs-vsctl --no-wait -- --may-exist add-br br-int
ovs-vsctl --no-wait set bridge br-int fail-mode=secure other-config:disable-in-band=true
ovs-vsctl --no-wait set bridge br-int external-ids:bridge-id="br-int"

ovs-vsctl --no-wait --may-exist add-br br-ex -- set bridge br-ex protocols=OpenFlow13
ovs-vsctl --no-wait set bridge br-ex external-ids:bridge-id="br-ex"
ovs-vsctl set open . external-ids:ovn-bridge-mappings=internet:br-ex

echo 'OVN controller is now installed'

echo 'Restarting openvswitch service'
echo 'Waiting for the services to start...'
sleep 3

echo 'Configure the kernel to enable packet forwarding and disable reverse path filting'
confset /etc/sysctl.conf net.ipv4.ip_forward 1
confset /etc/sysctl.conf net.ipv4.conf.default.rp_filter 0
confset /etc/sysctl.conf net.ipv4.conf.all.rp_filter 0

echo 'Load the new kernel configuration'
sysctl -p

service nova-compute start

echo 'Services on compute node started!'

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


ovs-vsctl add-port br-ex $leap_publicnic;ifconfig $leap_publicnic 0.0.0.0;ifconfig br-ex $br_ex_ip
