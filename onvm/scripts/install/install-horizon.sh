#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

apt-get -qqy "$leap_aptopt" install openstack-dashboard

cmdStr=$(echo 's/^OPENSTACK_HOST = "127.0.0.1"/OPENSTACK_HOST = "'$leap_logical2physical_keystone'"/g')

sed -i -e "${cmdStr}" /etc/openstack-dashboard/local_settings.py
sed -i -e 's/^OPENSTACK_KEYSTONE_DEFAULT_ROLE = "_member_"/OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"/g' /etc/openstack-dashboard/local_settings.py

echo 'Set up time zone...'
cmdStr=$(echo 's/^TIME_ZONE = "UTC"/TIME_ZONE = "'$leap_timezone'"/g')
sed -i -e "${cmdStr}" /etc/openstack-dashboard/local_settings.py

echo 'Setup allowed hosts...'
sed -i -e "s/^ALLOWED_HOSTS = '\*'/ALLOWED_HOSTS = ['*', ]/" /etc/openstack-dashboard/local_settings.py

# Do this to make the browser go to the horizon app
cp /onvm/conf/index.html /var/www/html

service apache2 reload

echo 'Horizon installation is now complete'