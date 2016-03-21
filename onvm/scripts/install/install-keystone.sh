#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

echo "manual" > /etc/init/keystone.override

apt-get install -qqy "$leap_aptopt" keystone apache2 libapache2-mod-wsgi memcached python-memcache

echo "Keystone packages are installed!"

iniset /etc/keystone/keystone.conf DEFAULT admin_token $1
iniset /etc/keystone/keystone.conf DEFAULT rpc_backend rabbit
iniset /etc/keystone/keystone.conf DEFAULT debug "True"

iniset /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:$1@$leap_logical2physical_mysqldb/keystone
iniset /etc/keystone/keystone.conf memcache servers "localhost:11211"
iniset /etc/keystone/keystone.conf token provider uuid
iniset /etc/keystone/keystone.conf token driver memcache
iniset /etc/keystone/keystone.conf revoke driver sql

iniset /etc/keystone/keystone.conf oslo_messaging_rabbit rabbit_host "${leap_logical2physical_rabbitmq}"
iniset /etc/keystone/keystone.conf oslo_messaging_rabbit rabbit_userid openstack
iniset /etc/keystone/keystone.conf oslo_messaging_rabbit rabbit_password $1

echo "ServerName ${leap_logical2physical_keystone}" >> /etc/apache2/apache2.conf

su -s /bin/sh -c "keystone-manage db_sync" keystone

echo "Keystone configuration is done!"

cp /onvm/conf/wsgi-keystone.conf /etc/apache2/sites-available/
ln -s /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled

iniremcomment /etc/keystone/keystone.conf

service apache2 restart

rm -f /var/lib/keystone/keystone.db

wait
echo "Ready to create endpoints"

export OS_TOKEN=$1
export OS_URL=http://$leap_logical2physical_keystone:35357/v3
export OS_IDENTITY_API_VERSION=3

openstack service create --name keystone --description "OpenStack Identity" identity
eval pub_ip=\$leap_${leap_logical2physical_keystone}_eth0; pub_ip=`echo $pub_ip`
openstack endpoint create --region RegionOne identity public http://$pub_ip:5000/v2.0
openstack endpoint create --region RegionOne identity internal http://$leap_logical2physical_keystone:5000/v2.0
openstack endpoint create --region RegionOne identity admin http://$leap_logical2physical_keystone:35357/v2.0

openstack project create --domain default --description "Admin Project" admin
openstack user create --domain default --password $1 admin
openstack role create admin
openstack role add --project admin --user admin admin
openstack project create --domain default --description "Service Project" service

openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default --password $1 demo

openstack role create user
openstack role add --project demo --user demo user


# Now setup two files for testing
echo "export OS_PROJECT_DOMAIN_ID=default" > ~/admin-openrc.sh
echo "export OS_USER_DOMAIN_ID=default" >> ~/admin-openrc.sh
echo "export OS_PROJECT_NAME=admin" >> ~/admin-openrc.sh
echo "export OS_TENANT_NAME=admin" >> ~/admin-openrc.sh
echo "export OS_USERNAME=admin" >> ~/admin-openrc.sh
echo "export OS_PASSWORD=$1" >> ~/admin-openrc.sh
echo "export OS_AUTH_URL=http://${pub_ip}:35357/v3" >> ~/admin-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> ~/admin-openrc.sh

echo "export OS_PROJECT_DOMAIN_ID=default" > ~/demo-openrc.sh
echo "export OS_USER_DOMAIN_ID=default" >> ~/demo-openrc.sh
echo "export OS_PROJECT_NAME=demo" >> ~/demo-openrc.sh
echo "export OS_TENANT_NAME=demo" >> ~/demo-openrc.sh
echo "export OS_USERNAME=demo" >> ~/demo-openrc.sh
echo "export OS_PASSWORD=$1" >> ~/demo-openrc.sh
echo "export OS_AUTH_URL=http://${pub_ip}:5000/v3" >> ~/demo-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> ~/demo-openrc.sh

for key in 'pipeline:public_api' 'pipeline:admin_api' 'pipeline:api_v3'; do
  val1=$(iniget /etc/keystone/keystone-paste.ini $key pipeline)
  val1=${val1/admin_token_auth/}
  iniset /etc/keystone/keystone-paste.ini $key pipeline "$val1"
done


unset OS_TOKEN
unset OS_URL
unset OS_IDENTITY_API_VERSION

echo "Set up endpoints for glance, cinder, nova, heat, ceilometer and neutron"

source ~/admin-openrc.sh
for key in keystone neutron nova glance cinder heat ceilometer; do
  openstack user create --domain default --password $1 $key
  openstack role add --project service --user $key admin
done

openstack service create --name glance --description "OpenStack Image service" image
eval pub_ip=\$leap_${leap_logical2physical_glance}_eth0; pub_ip=`echo $pub_ip`
openstack endpoint create --region RegionOne image public http://$pub_ip:9292
openstack endpoint create --region RegionOne image internal http://$leap_logical2physical_glance:9292
openstack endpoint create --region RegionOne image admin http://$leap_logical2physical_glance:9292

openstack service create --name nova --description "OpenStack Compute" compute
eval pub_ip=\$leap_${leap_logical2physical_nova}_eth0; pub_ip=`echo $pub_ip`
openstack endpoint create --region RegionOne compute public http://$pub_ip:8774/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute internal http://$leap_logical2physical_nova:8774/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute admin http://$leap_logical2physical_nova:8774/v2/%\(tenant_id\)s

openstack service create --name neutron --description "OpenStack Networking" network
eval pub_ip=\$leap_${leap_logical2physical_neutron}_eth0; pub_ip=`echo $pub_ip`
openstack endpoint create --region RegionOne network public http://$pub_ip:9696
openstack endpoint create --region RegionOne network internal http://$leap_logical2physical_neutron:9696
openstack endpoint create --region RegionOne network admin http://$leap_logical2physical_neutron:9696

openstack service create --name ceilometer --description "OpenStack Telemetry" metering
eval pub_ip=\$leap_${leap_logical2physical_ceilometer}_eth0; pub_ip=`echo $pub_ip`
openstack endpoint create --region RegionOne metering public http://$pub_ip:8777
openstack endpoint create --region RegionOne metering internal http://$leap_logical2physical_ceilometer:8777
openstack endpoint create --region RegionOne metering admin http://$leap_logical2physical_ceilometer:8777


openstack service create --name cinder --description "OpenStack Block Storage" volume
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
eval pub_ip=\$leap_${leap_logical2physical_cinder}_eth0; pub_ip=`echo $pub_ip`
openstack endpoint create --region RegionOne volume public http://$pub_ip:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volume internal http://$leap_logical2physical_cinder:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volume admin http://$leap_logical2physical_cinder:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 public http://$pub_ip:8776/v2/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 internal http://$leap_logical2physical_cinder:8776/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev2 admin http://$leap_logical2physical_cinder:8776/v1/%\(tenant_id\)s


# Orchestration setups
openstack service create --name heat --description "Orchestration" orchestration
openstack service create --name heat-cfn --description "Orchestration"  cloudformation
eval pub_ip=\$leap_${leap_logical2physical_heat}_eth0; pub_ip=`echo $pub_ip`
openstack endpoint create --region RegionOne orchestration public http://$pub_ip:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne orchestration internal http://$leap_logical2physical_heat:8004/v1/%\(tenant_id\)s
openstack endpoint create --region RegionOne orchestration admin http://$leap_logical2physical_heat:8004/v1/%\(tenant_id\)s

openstack endpoint create --region RegionOne cloudformation public http://$pub_ip:8000/v1
openstack endpoint create --region RegionOne cloudformation internal http://$leap_logical2physical_heat:8000/v1
openstack endpoint create --region RegionOne cloudformation admin http://$leap_logical2physical_heat:8000/v1

openstack domain create --description "Stack projects and users" heat
openstack user create --domain heat --password $1 heat_domain_admin
openstack role add --domain heat --user heat_domain_admin admin
openstack role create heat_stack_owner
openstack role add --project demo --user demo heat_stack_owner
openstack role create heat_stack_user

mkdir -p /storage
sp=$(lvdisplay | grep /dev/vg02/storage)
if [ ! "$sp" ];then
  echo 'Ready to create storage'
  lvcreate -l 100%FREE -n storage vg02
  mkfs -t ext4 /dev/vg02/storage
fi

sp=$(mount | grep /storage)
if [ ! "$sp" ]; then
  mount /dev/vg02/storage /storage/
  echo '/dev/mapper/vg02-storage    /storage    ext4    errors=continue    0    0' >> /etc/fstab
fi


echo "Keystone setup is now complete!"
