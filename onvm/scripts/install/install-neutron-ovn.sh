#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

echo "racoon racoon/config_mode select direct" | debconf-set-selections

apt-get install -qqy "$leap_aptopt" dkms ipsec-tools debconf-utils
apt-get install -qqy "$leap_aptopt" graphviz autoconf automake bzip2 \
  debhelper dh-autoreconf libssl-dev libtool openssl procps python-all \
  python-qt4 python-twisted-conch python-zopeinterface python-six
apt-get install -qqy "$leap_aptopt" racoon

echo 'All dependencies are now installed!'

debloc='/leapbin'
dpkg -i "$debloc"/openvswitch-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-switch_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-datapath-dkms_2.5.90-1_all.deb
dpkg -i "$debloc"/python-openvswitch_2.5.90-1_all.deb
dpkg -i "$debloc"/openvswitch-ipsec_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-pki_2.5.90-1_all.deb
dpkg -i "$debloc"/openvswitch-vtep_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-central_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-host_2.5.90-1_amd64.deb

echo 'All OVN packages are installed!'

modprobe -r vport_geneve
modprobe -r openvswitch

modprobe openvswitch
modprobe vport_geneve

echo 'Start openvswitch services'
service openvswitch-switch restart


echo 'Creating ovn databases...'
mkdir -p /var/ovn /var/log/ovn
# Create openvswitch, northbound and southbound ovn database
ovsdb-tool create /var/ovn/conf.db /onvm/conf/vswitch.ovsschema
ovsdb-tool create /var/ovn/ovnsb.db /onvm/conf/ovn-sb.ovsschema
ovsdb-tool create /var/ovn/ovnnb.db /onvm/conf/ovn-nb.ovsschema

ovs-appctl -t ovsdb-server ovsdb-server/add-remote ptcp:6640:$3


echo 'Start ovn-northd...'

ovn-northd --db-nb-sock=/var/ovn/ovnsb.sock \
           --db-sb-sock=/var/ovn/ovnnb.sock \
           --db-nb-pid=/var/ovn/ovsdb-server-nb.pid \
           --db-sb-pid=/var/ovn/ovsdb-server-sb.pid \
           --ovn-northd-log=/--log-file=/var/log/ovn-northd.log

# Install neutron, dhcp, metadata server and neutron client
apt-get install -qqy "$leap_aptopt" neutron-server \
  neutron-dhcp-agent neutron-metadata-agent python-neutronclient


echo "Neutron and ovn packages are installed!"

# Configre /etc/neutron/neutron.conf
echo "Configure the server component"

iniset /etc/neutron/neutron.conf database connection "mysql+pymysql://neutron:$1@${leap_logical2physical_mysqldb}/neutron"
iniset /etc/neutron/neutron.conf DEFAULT core_plugin 'networking_ovn.plugin.OVNPlugin'
iniset /etc/neutron/neutron.conf DEFAULT service_plugins "qos"
iniset /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips 'True'
iniset /etc/neutron/neutron.conf DEFAULT rpc_backend 'rabbit'
iniset /etc/neutron/neutron.conf DEFAULT auth_strategy 'keystone'
iniset /etc/neutron/neutron.conf DEFAULT debug 'True'

iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host "${leap_logical2physical_rabbitmq}"
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid 'openstack'
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $1

iniset /etc/neutron/neutron.conf keystone_authtoken auth_uri "http://${leap_logical2physical_keystone}:5000"
iniset /etc/neutron/neutron.conf keystone_authtoken auth_url "http://${leap_logical2physical_keystone}:35357"
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

iniset /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes 'True'
iniset /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes 'True'
iniset /etc/neutron/neutron.conf DEFAULT nova_url "http://${leap_logical2physical_nova}:8774/v2"

iniset /etc/neutron/neutron.conf nova auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/neutron/neutron.conf nova auth_plugin 'password'
iniset /etc/neutron/neutron.conf nova project_domain_id 'default'
iniset /etc/neutron/neutron.conf nova user_domain_id 'default'
iniset /etc/neutron/neutron.conf nova region_name 'RegionOne'
iniset /etc/neutron/neutron.conf nova project_name 'service'
iniset /etc/neutron/neutron.conf nova username 'nova'
iniset /etc/neutron/neutron.conf nova password $1

# Configure /etc/neutron/plugins/ml2/ml2_conf.ini
echo "Configure Modular Layer 2 (ML2) plug-in"

iniset /etc/neutron/plugins/networking-ovn/networking-ovn.ini ovn ovsdb_connection tcp:$3:6640
iniset /etc/neutron/plugins/networking-ovn/networking-ovn.ini ovn ovn ovn_l3_mode True


# Configure /etc/neutron/dhcp_agent.ini
echo "Configure the DHCP agent"


OVN_NATIVE_MTU=${OVN_NATIVE_MTU:-1500}
iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver 'neutron.agent.linux.dhcp.Dnsmasq'
iniset /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata 'True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces ' True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces 'True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file '/etc/neutron/dnsmasq-neutron.conf'

echo "dhcp-option=26,$(($OVN_NATIVE_MTU - 58))" | tee -a /etc/neutron/dnsmasq-neutron.conf

#Configure /etc/neutron/metadata_agent.ini
echo "Configure the metadata agent"

iniset /etc/neutron/metadata_agent.ini DEFAULT auth_uri "http://${leap_logical2physical_keystone}:5000"
iniset /etc/neutron/metadata_agent.ini DEFAULT auth_url "http://${leap_logical2physical_keystone}:35357"
iniset /etc/neutron/metadata_agent.ini DEFAULT auth_region 'RegionOne'
iniset /etc/neutron/metadata_agent.ini DEFAULT auth_plugin 'password'
iniset /etc/neutron/metadata_agent.ini DEFAULT project_domain_id 'default'
iniset /etc/neutron/metadata_agent.ini DEFAULT user_domain_id 'default'
iniset /etc/neutron/metadata_agent.ini DEFAULT project_name 'service'
iniset /etc/neutron/metadata_agent.ini DEFAULT username 'neutron'
iniset /etc/neutron/metadata_agent.ini DEFAULT password $1

metahost=$(echo '$leap_'$leap_logical2physical_nova'_eth1')
eval metahost=$metahost
iniset /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip $metahost
iniset /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $1
iniset /etc/neutron/metadata_agent.ini DEFAULT debug 'True'

inidelete /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name
inidelete /etc/neutron/metadata_agent.ini DEFAULT admin_user
inidelete /etc/neutron/metadata_agent.ini DEFAULT admin_password

# clean up configuration files

iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/plugins/ml2/ml2_conf.ini
iniremcomment /etc/neutron/dhcp_agent.ini
iniremcomment /etc/neutron/metadata_agent.ini


service neutron-server restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart

rm -f /var/lib/neutron/neutron.sqlite

echo "Neutron setup is now complete!"

