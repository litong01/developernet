#!/usr/bin/env bash
# $1 sys_password

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

apt-get -qqy install ceilometer-collector ceilometer-agent-notification

iniset /etc/ceilometer/ceilometer.conf DEFAULT debug 'True'
iniset /etc/ceilometer/ceilometer.conf DEFAULT auth_strategy 'keystone'
iniset /etc/ceilometer/ceilometer.conf DEFAULT dispatcher 'http'
iniset /etc/ceilometer/ceilometer.conf DEFAULT transport_url "rabbit://openstack:$1@${leap_logical2physical_rabbitmq}:5672/"
iniset /etc/ceilometer/ceilometer.conf DEFAULT notification_driver messagingv2

iniset /etc/ceilometer/ceilometer.conf database connection mysql+pymysql://ceilometer:$1@$leap_logical2physical_mysqldb/ceilometer

iniset /etc/ceilometer/ceilometer.conf  keystone_authtoken auth_uri http://$leap_logical2physical_keystone:5000
iniset /etc/ceilometer/ceilometer.conf  keystone_authtoken auth_url http://$leap_logical2physical_keystone:35357
iniset /etc/ceilometer/ceilometer.conf  keystone_authtoken auth_type 'password'
iniset /etc/ceilometer/ceilometer.conf  keystone_authtoken project_domain_name 'Default'
iniset /etc/ceilometer/ceilometer.conf  keystone_authtoken user_domain_name 'Default'
iniset /etc/ceilometer/ceilometer.conf  keystone_authtoken project_name 'service'
iniset /etc/ceilometer/ceilometer.conf  keystone_authtoken username 'ceilometer'
iniset /etc/ceilometer/ceilometer.conf  keystone_authtoken password $1

iniset /etc/ceilometer/ceilometer.conf  service_credentials auth_url http://$leap_logical2physical_keystone:5000
iniset /etc/ceilometer/ceilometer.conf  service_credentials username 'ceilometer'
iniset /etc/ceilometer/ceilometer.conf  service_credentials tenant_name 'service'
iniset /etc/ceilometer/ceilometer.conf  service_credentials password $1
iniset /etc/ceilometer/ceilometer.conf  service_credentials region_name 'RegionOne'
iniset /etc/ceilometer/ceilometer.conf  service_credentials endpoint_type 'internalURL'

#iniset /etc/ceilometer/ceilometer.conf dispatcher_http target "${leap_qradar_endpoint}"
#iniset /etc/ceilometer/ceilometer.conf dispatcher_http event_target "${leap_qradar_endpoint}"
#iniset /etc/ceilometer/ceilometer.conf dispatcher_http cadf_only "${leap_cadf_only}"

iniset /etc/ceilometer/ceilometer.conf meter meter_definitions_cfg_file '/etc/ceilometer/meters.yaml'

iniset /etc/ceilometer/ceilometer.conf notification disable_non_metric_meters true
iniset /etc/ceilometer/ceilometer.conf notification store_events false

iniset /etc/ceilometer/ceilometer.conf publisher_notifier metering_topic 'metering'

#cp /onvm/conf/meters.yaml /etc/ceilometer/meters.yaml
#cp /onvm/conf/pipeline.yaml /etc/ceilometer/pipeline.yaml

#chmod +x /onvm/conf/getpath.py
#c_dir=`/onvm/conf/getpath.py`

#cp /onvm/conf/http.py $c_dir/dispatcher/http.py

iniremcomment /etc/ceilometer/ceilometer.conf

service ceilometer-agent-notification restart
service ceilometer-collector restart
