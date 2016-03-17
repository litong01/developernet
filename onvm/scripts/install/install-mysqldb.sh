#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

debconf-set-selections <<< "mariadb-server-5.5 mysql-server/root_password password $1"
debconf-set-selections <<< "mariadb-server-5.5 mysql-server/root_password_again password $1"

apt-get -qqy "$leap_aptopt" install mariadb-server python-pymysql

echo "Installed MariaDB!"

iniset /etc/mysql/conf.d/mysqld_openstack.cnf mysqld bind-address $3
iniset /etc/mysql/conf.d/mysqld_openstack.cnf mysqld performance_schema off
iniset /etc/mysql/conf.d/mysqld_openstack.cnf mysqld default-storage-engine innodb
iniset /etc/mysql/conf.d/mysqld_openstack.cnf mysqld innodb_file_per_table on
iniset /etc/mysql/conf.d/mysqld_openstack.cnf mysqld collation-server utf8_general_ci
iniset /etc/mysql/conf.d/mysqld_openstack.cnf mysqld init-connect 'SET NAMES utf8'
iniset /etc/mysql/conf.d/mysqld_openstack.cnf mysqld character-set-server utf8

wait
service mysql restart

# Create needed databases
IFS=. read -ra parts <<< $3 && subnet=`echo ${parts[0]}.${parts[1]}.${parts[2]}.%`
echo "Management network:"${subnet}
for db in keystone neutron nova glance cinder heat ceilometer; do
  mysql -uroot -p$1 -e "CREATE DATABASE $db;"
  mysql -uroot -p$1 -e "use $db; GRANT ALL PRIVILEGES ON $db.* TO '$db'@'localhost' IDENTIFIED BY '$1';"
  mysql -uroot -p$1 -e "use $db; GRANT ALL PRIVILEGES ON $db.* TO '$db'@'%' IDENTIFIED BY '$1';"
done

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

