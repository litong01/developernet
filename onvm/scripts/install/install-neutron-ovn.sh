#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

apt-get install -qqy git python-dev
easy_install -U pip

echo 'All dependencies are now installed!'

apt-get install -qqy dkms openvswitch-common openvswitch-switch ovn-common \
  ovn-central

echo 'All OVN packages are installed!'
echo 'Grant permission to the ovsdb so others can access via eth1 interface'

# OVN Northbound database needs open for neutron ovn plugin
ovs-appctl -t ovsdb-server ovsdb-server/add-remote ptcp:6641:$3

# OVN Southbound database needs open to compute nodes
ovs-appctl -t ovsdb-server ovsdb-server/add-remote ptcp:6642:$3


neutronhost=$(echo '$leap_'$leap_logical2physical_neutron'_eth1')
eval neutronhost=$neutronhost

echo "export OVN_NB_DB=tcp:$neutronhost:6641" >> ~/.bash_profile
echo "export OVN_SB_DB=tcp:$neutronhost:6642" >> ~/.bash_profile
export OVN_NB_DB=tcp:$neutronhost:6641
export OVN_SB_DB=tcp:$neutronhost:6642


echo 'Start openvswitch services'
service openvswitch-switch restart
service ovn-central restart

echo 'OVS OVN installation is now complete!'


#============================================================
echo 'Install Neutron Server...'
apt-get install -qqy "$leap_aptopt" neutron-server
service neutron-server stop

rm -r -f /var/log/neutron/*
#========================================================================
echo 'Install networking-ovn from source...'
git clone -b stable/newton https://github.com/openstack/networking-ovn /opt/networking-ovn
cd /opt/networking-ovn
pip install -r requirements.txt
python setup.py install

echo "Neutron and ovn packages are installed!"

# Configre /etc/neutron/neutron.conf
echo "Configure the server component"

iniset /etc/neutron/neutron.conf database connection "mysql+pymysql://neutron:$1@${leap_logical2physical_mysqldb}/neutron"
iniset /etc/neutron/neutron.conf DEFAULT core_plugin 'neutron.plugins.ml2.plugin.Ml2Plugin'
iniset /etc/neutron/neutron.conf DEFAULT service_plugins 'networking_ovn.l3.l3_ovn.OVNL3RouterPlugin'
iniset /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips 'True'
iniset /etc/neutron/neutron.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/neutron/neutron.conf DEFAULT auth_strategy 'keystone'
iniset /etc/neutron/neutron.conf DEFAULT bind_host '0.0.0.0'
iniset /etc/neutron/neutron.conf DEFAULT debug 'True'
iniset /etc/neutron/neutron.conf DEFAULT network_scheduler_driver 'neutron.scheduler.dhcp_agent_scheduler.AZAwareWeightScheduler'
iniset /etc/neutron/neutron.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"

iniset /etc/neutron/neutron.conf DEFAULT dhcp_load_type 'networks'
iniset /etc/neutron/neutron.conf DEFAULT dhcp_agents_per_network 2

iniset /etc/neutron/neutron.conf ovn ovn_l3_mode True
iniset /etc/neutron/neutron.conf ovn ovn_nb_connection tcp:$3:6641
iniset /etc/neutron/neutron.conf ovn ovn_sb_connection tcp:$3:6642

mkdir -p /var/lib/neutron
iniset /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron

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
echo "Configure OVN plugin"

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types geneve
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers port_security
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers 'local,flat,geneve'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers 'ovn,logger'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_geneve vni_ranges '1:65536'
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_geneve max_header_size '58'

iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovn ovn_l3_mode True
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovn ovn_nb_connection tcp:$3:6641
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovn ovn_sb_connection tcp:$3:6642
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovn ovn_native_dhcp True
iniset /etc/neutron/plugins/ml2/ml2_conf.ini ovn ovn_l3_scheduler leastloaded

echo 'Configure the kernel to enable packet forwarding and disable reverse path filting'
confset /etc/sysctl.conf net.ipv4.ip_forward 1
confset /etc/sysctl.conf net.ipv4.conf.default.rp_filter 0
confset /etc/sysctl.conf net.ipv4.conf.all.rp_filter 0

echo 'Load the new kernel configuration'
sysctl -p


# clean up configuration files
iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/plugins/ml2/ml2_conf.ini

neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head

neutron-ovn-db-sync-util --ovn-neutron_sync_mode=repair \
  --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini

sleep 10

service neutron-server start

rm -f /var/lib/neutron/neutron.sqlite

echo "Neutron setup is now complete!"

