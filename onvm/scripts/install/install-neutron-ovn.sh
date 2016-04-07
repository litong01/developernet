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
apt-get install -qqy git python-dev
easy_install -U pip

echo 'All dependencies are now installed!'

debloc='/leapbin'
dpkg -i "$debloc"/openvswitch-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-switch_2.5.90-1_amd64.deb
#dpkg -i "$debloc"/openvswitch-datapath-dkms_2.5.90-1_all.deb
#dpkg -i "$debloc"/python-openvswitch_2.5.90-1_all.deb
#dpkg -i "$debloc"/openvswitch-ipsec_2.5.90-1_amd64.deb
#dpkg -i "$debloc"/openvswitch-pki_2.5.90-1_all.deb
#dpkg -i "$debloc"/openvswitch-vtep_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-central_2.5.90-1_amd64.deb
#dpkg -i "$debloc"/ovn-host_2.5.90-1_amd64.deb

echo 'All OVN packages are installed!'

echo 'Start openvswitch services'
service openvswitch-switch restart
service ovn-central restart

echo 'OVS OVN installation is now complete!'

echo 'Install Neutron Server...'
apt-get install -qqy "$leap_aptopt" neutron-server
rm -r -f /etc/neutron/plugins

echo 'Install networking-ovn from source...'
git clone https://github.com/openstack/networking-ovn /opt/networking-ovn
cd /opt/networking-ovn
pip install -r requirements.txt

python setup.py install

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

# Configure /etc/neutron/plugins/networking-ovn/networking-ovn.ini
echo "Configure OVN plugin"
mkdir -p /etc/neutron/plugins/networking-ovn
iniset /etc/neutron/plugins/networking-ovn/networking-ovn.ini ovn ovsdb_connection tcp:$3:6641
iniset /etc/neutron/plugins/networking-ovn/networking-ovn.ini ovn ovn ovn_l3_mode True

# clean up configuration files

iniremcomment /etc/neutron/neutron.conf
iniremcomment /etc/neutron/plugins/networking-ovn/networking-ovn.ini

service neutron-server restart

rm -f /var/lib/neutron/neutron.sqlite

echo "Neutron setup is now complete!"

