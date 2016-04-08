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

debloc='/leapbin'
dpkg -i "$debloc"/openvswitch-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/openvswitch-switch_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-common_2.5.90-1_amd64.deb
dpkg -i "$debloc"/ovn-host_2.5.90-1_amd64.deb

service openvswitch-switch restart
service ovn-host restart

echo 'OVN controller is now installed'
echo 'Install neutron dhcp and metadata agent'
apt-get install -qqy "$leap_aptopt" neutron-dhcp-agent neutron-metadata-agent


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
iniremcomment /etc/neutron/dhcp_agent.ini
iniremcomment /etc/neutron/metadata_agent.ini