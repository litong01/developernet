#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

#echo "racoon racoon/config_mode select direct" | debconf-set-selections

#apt-get install -qqy "$leap_aptopt" dkms ipsec-tools debconf-utils
#apt-get install -qqy "$leap_aptopt" graphviz autoconf automake bzip2 \
#  debhelper dh-autoreconf libssl-dev libtool openssl procps python-all \
#  python-qt4 python-twisted-conch python-zopeinterface python-six
#apt-get install -qqy "$leap_aptopt" racoon

apt-get install -qqy git python-dev
easy_install -U pip

echo 'All dependencies are now installed!'

debloc='/leapbin'
dpkg -i "$debloc"/openvswitch-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-switch_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-central_2.5.90-1_amd64.deb

echo 'All OVN packages are installed!'
echo 'Grant permission to the ovsdb so others can access via eth1 interface'

# OVN Northbound database needs open for neutron ovn plugin
ovs-appctl -t ovsdb-server ovsdb-server/add-remote ptcp:6641:$3

# OVN Southbound database needs open to compute nodes
ovs-appctl -t ovsdb-server ovsdb-server/add-remote ptcp:6642:$3

echo 'Start openvswitch services'
service openvswitch-switch restart
service ovn-central restart

echo 'OVS OVN installation is now complete!'


#============================================================
echo 'Install Neutron Server...'
git clone https://github.com/openstack/neutron /opt/neutron
cd /opt/neutron
pip install -r requirements.txt
pip install pymysql
python setup.py install
./tools/generate_config_file_samples.sh

mkdir -p /etc/neutron/plugins/networking-ovn
cp -r etc/neutron/* /etc/neutron
cp etc/api-paste.ini /etc/neutron
cp etc/policy.json /etc/neutron
cp etc/rootwrap.conf /etc/neutron
cp etc/neutron.conf.sample /etc/neutron/neutron.conf


#========================================================================
echo 'Install networking-ovn from source...'
git clone https://github.com/openstack/networking-ovn /opt/networking-ovn
cd /opt/networking-ovn
pip install -r requirements.txt

pip uninstall amqp
pip install amqp==1.4.9

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
iniset /etc/neutron/neutron.conf DEFAULT bind_host '0.0.0.0'
iniset /etc/neutron/neutron.conf DEFAULT debug 'True'
iniset /etc/neutron/neutron.conf DEFAULT network_scheduler_driver 'neutron.scheduler.dhcp_agent_scheduler.AZAwareWeightScheduler'

iniset /etc/neutron/neutron.conf agent root_helper_daemon 'sudo /usr/local/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf'
iniset /etc/neutron/neutron.conf agent root_helper 'sudo /usr/local/bin/neutron-rootwrap /etc/neutron/rootwrap.conf'


iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host "${leap_logical2physical_rabbitmq}"
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid 'openstack'
iniset /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $1

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

# Configure /etc/neutron/plugins/networking-ovn/networking_ovn.ini
echo "Configure OVN plugin"

# networking ovn plugin should only access northbound database
iniset /etc/neutron/plugins/networking-ovn/networking_ovn.ini ovn ovsdb_connection tcp:$3:6641
iniset /etc/neutron/plugins/networking-ovn/networking_ovn.ini ovn ovn ovn_l3_mode True


# Configure /etc/neutron/dhcp_agent.ini
echo "Configure the DHCP agent"

iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver 'neutron.agent.linux.dhcp.Dnsmasq'
iniset /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata 'True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces ' True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces 'True'
iniset /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file '/etc/neutron/dnsmasq-neutron.conf'

iniset /etc/neutron/dhcp_agent.ini DEFAULT dhcp_agent_manager 'neutron.agent.dhcp_agent.DhcpAgentWithStateReport'
iniset /etc/neutron/dhcp_agent.ini DEFAULT interface_driver 'openvswitch'

iniset /etc/neutron/dhcp_agent.ini AGENT availability_zone nova
iniset /etc/neutron/dhcp_agent.ini AGENT root_helper_daemon 'sudo /usr/local/bin/neutron-rootwrap-daemon /etc/neutron/rootwrap.conf'
iniset /etc/neutron/dhcp_agent.ini AGENT root_helper 'sudo /usr/local/bin/neutron-rootwrap /etc/neutron/rootwrap.conf'

echo 'dhcp-option-force=26,1454' > /etc/neutron/dnsmasq-neutron.conf

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
iniremcomment /etc/neutron/plugins/networking-ovn/networking_ovn.ini
iniremcomment /etc/neutron/dhcp_agent.ini
iniremcomment /etc/neutron/metadata_agent.ini

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/networking-ovn/networking_ovn.ini upgrade head"

mkdir -p /var/log/neutron

neutron-server --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/networking-ovn/networking_ovn.ini \
  --logfile /var/log/neutron/server.log > /dev/null 2>&1 &

neutron-dhcp-agent --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/networking-ovn/networking_ovn.ini \
  --config-file /etc/neutron/dhcp_agent.ini \
  --logfile /var/log/neutron/dhcp.log > /dev/null 2>&1 &

neutron-metadata-agent --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/networking-ovn/networking_ovn.ini \
  --config-file /etc/neutron/metadata_agent.ini \
  --logfile /var/log/neutron/metadata.log > /dev/null 2>&1 &


rm -f /var/lib/neutron/neutron.sqlite

echo "Neutron setup is now complete!"

