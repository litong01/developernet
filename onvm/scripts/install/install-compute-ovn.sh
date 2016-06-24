#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

apt-get install -qqy git python-dev
easy_install -U pip


apt-get install -qqy "$leap_aptopt" nova-compute sysfsutils

echo "Compute packages are installed!"

iniset /etc/nova/nova.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/nova/nova.conf DEFAULT debug 'True'
iniset /etc/nova/nova.conf DEFAULT auth_strategy 'keystone'
iniset /etc/nova/nova.conf DEFAULT my_ip $3
iniset /etc/nova/nova.conf DEFAULT enabled_apis 'osapi_compute,metadata'

iniset /etc/nova/nova.conf DEFAULT network_api_class 'nova.network.neutronv2.api.API'
iniset /etc/nova/nova.conf DEFAULT use_neutron 'True'
#iniset /etc/nova/nova.conf DEFAULT security_group_api 'neutron'
#iniset /etc/nova/nova.conf DEFAULT linuxnet_interface_driver 'nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver'
iniset /etc/nova/nova.conf DEFAULT firewall_driver 'nova.virt.firewall.NoopFirewallDriver'

metahost=$(echo '$leap_'$leap_logical2physical_nova'_eth1')
eval metahost=$metahost
iniset /etc/nova/nova.conf DEFAULT metadata_host $metahost
iniset /etc/nova/nova.conf DEFAULT instances_path $leap_instances_path

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
iniset /etc/nova/nova.conf keystone_authtoken auth_type 'password'
iniset /etc/nova/nova.conf keystone_authtoken project_domain_name 'default'
iniset /etc/nova/nova.conf keystone_authtoken user_domain_name 'default'
iniset /etc/nova/nova.conf keystone_authtoken project_name 'service'
iniset /etc/nova/nova.conf keystone_authtoken username 'nova'
iniset /etc/nova/nova.conf keystone_authtoken password $1


# Configure compute to use Networking
iniset /etc/nova/nova.conf neutron url http://$leap_logical2physical_neutron:9696
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


echo 'Install OVN from the local build'
debloc='/leapbin'
apt-get install -qqy build-essential dkms
dpkg -i "$debloc"/openvswitch-datapath-dkms_2.5.90-1_all.deb
dpkg -i "$debloc"/openvswitch-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-switch_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/python-openvswitch_2.5.90-1_all.deb
dpkg -i "$debloc"/ovn-host_2.5.90-1_amd64.deb

neutronhost=$(echo '$leap_'$leap_logical2physical_neutron'_eth1')
eval neutronhost=$neutronhost


echo "export OVN_NB_DB=tcp:$neutronhost:6641" >> ~/.bash_profile
echo "export OVN_SB_DB=tcp:$neutronhost:6642" >> ~/.bash_profile
export OVN_NB_DB=tcp:$neutronhost:6641
export OVN_SB_DB=tcp:$neutronhost:6642

ovs-vsctl --no-wait -- --may-exist add-br br-int
ovs-vsctl --no-wait set bridge br-int fail-mode=secure other-config:disable-in-band=true

ovs-vsctl --may-exist add-br br-provider -- set bridge br-provider protocols=OpenFlow13
ovs-vsctl set open . external-ids:ovn-bridge-mappings=internet:br-provider


ovs-vsctl --no-wait set open_vswitch . external-ids:ovn-remote=tcp:$neutronhost:6642
ovs-vsctl --no-wait set open_vswitch . external-ids:ovn-bridge="br-int"
ovs-vsctl --no-wait set open_vswitch . external-ids:ovn-encap-type=geneve
ovs-vsctl --no-wait set open_vswitch . external-ids:ovn-encap-ip=$3

#echo 'OpenVSwitch configuration is done.'

#vtep-ctl add-ps br-vtep
#vtep-ctl set Physical_Switch br-vtep tunnel_ips=$3

echo 'OVN controller is now installed'

echo 'Restarting openvswitch service'
echo 'Waiting for the services to start...'
sleep 3

echo 'Install DHCP & Metadata Agents...'
git clone https://github.com/openstack/neutron /opt/neutron
cd /opt/neutron
git reset --hard 928e16c21337e26b1e2eaa43044826419d4bace5
pip install -r requirements.txt
pip install pymysql
python setup.py install
./tools/generate_config_file_samples.sh

mkdir -p /etc/neutron/plugins/ml2
mkdir -p /var/lib/neutron
cp -r etc/neutron/* /etc/neutron
cp etc/api-paste.ini /etc/neutron
cp etc/policy.json /etc/neutron
cp etc/rootwrap.conf /etc/neutron
cp etc/neutron.conf.sample /etc/neutron/neutron.conf

iniset /etc/neutron/neutron.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/neutron/neutron.conf nova region_name 'RegionOne'
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host "${leap_logical2physical_rabbitmq}"
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid 'openstack'
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $1
iniset /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron



# Configure /etc/neutron/dhcp_agent.ini
echo "Configure the DHCP agent"

iniset /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata 'True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT enable_metadata_network 'False'
iniset /etc/neutron/dhcp_agent.ini DEFAULT debug 'True'

iniset /etc/neutron/dhcp_agent.ini DEFAULT ovs_use_veth 'False'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file '/etc/neutron/dnsmasq-neutron.conf'
iniset /etc/neutron/dhcp_agent.ini DEFAULT interface_driver 'openvswitch'

iniset /etc/neutron/dhcp_agent.ini AGENT availability_zone nova
iniset /etc/neutron/dhcp_agent.ini AGENT root_helper_daemon 'sudo /usr/local/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf'
iniset /etc/neutron/dhcp_agent.ini AGENT root_helper 'sudo /usr/local/bin/neutron-rootwrap /etc/neutron/rootwrap.conf'

echo 'dhcp-option-force=26,1442' > /etc/neutron/dnsmasq-neutron.conf

iniset /etc/neutron/rootwrap.conf DEFAULT filters_path '/etc/neutron/rootwrap.d'

echo 'dhcp agent configuration is complete!'

#Configure /etc/neutron/metadata_agent.ini
echo 'Configure the metadata agent' 

metahost=$(echo '$leap_'$leap_logical2physical_nova'_eth1')
eval metahost=$metahost
iniset /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $metahost
iniset /etc/neutron/metadata_agent.ini DEFAULT debug 'True'

iniset /etc/neutron/metadata_agent.ini AGENT root_helper_daemon 'sudo /usr/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf'
iniset /etc/neutron/metadata_agent.ini AGENT root_helper 'sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf'

# clean up configuration files
iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/dhcp_agent.ini
iniremcomment /etc/neutron/metadata_agent.ini


echo 'Configure the kernel to enable packet forwarding and disable reverse path filting'
confset /etc/sysctl.conf net.ipv4.ip_forward 1
confset /etc/sysctl.conf net.ipv4.conf.default.rp_filter 0
confset /etc/sysctl.conf net.ipv4.conf.all.rp_filter 0

echo 'Load the new kernel configuration'
sysctl -p

mkdir -p /var/log/neutron


service nova-compute restart
#service openvswitch-switch restart
#service ovn-host restart

neutron-dhcp-agent --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/dhcp_agent.ini \
  --logfile /var/log/neutron/dhcp.log > /dev/null 2>&1 &

neutron-metadata-agent --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/metadata_agent.ini \
  --logfile /var/log/neutron/metadata.log > /dev/null 2>&1 &

echo 'Services on compute node started!'

echo "Adding public nic to ovs bridge..."
br_ex_ip=$(ifconfig $leap_pubnic | awk -F"[: ]+" '/inet addr:/ {print $4}')
ovs-vsctl add-port br-provider $leap_pubnic;ifconfig $leap_pubnic 0.0.0.0;ifconfig br-provider $br_ex_ip

# The following line will make the machine lose connectivity.
#ip addr flush dev $leap_pubnic;ip addr add $br_ex_ip dev br-provider;ip link set br-provider up;ovs-vsctl add-port br-provider $leap_pubnic
