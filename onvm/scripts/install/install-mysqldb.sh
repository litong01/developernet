#!/usr/bin/env bash
# $1 sys_password

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')
apt-get update

debconf-set-selections <<< "mariadb-server-5.5 mysql-server/root_password password $1"
debconf-set-selections <<< "mariadb-server-5.5 mysql-server/root_password_again password $1"

apt-get -qqy "$leap_aptopt" install mariadb-server python-pymysql

echo "Installed MariaDB!"

tun_cidr=$(ip -4 addr show $leap_tunnelnic | awk -F '/' '/inet / {print $1}')
arr=($tun_cidr); my_ip="${arr[1]}"

iniset /etc/mysql/mariadb.conf.d/99-openstack.cnf mysqld bind-address $my_ip
iniset /etc/mysql/mariadb.conf.d/99-openstack.cnf mysqld default-storage-engine innodb
iniset /etc/mysql/mariadb.conf.d/99-openstack.cnf mysqld innodb_file_per_table on
iniset /etc/mysql/mariadb.conf.d/99-openstack.cnf mysqld collation-server utf8_general_ci
iniset /etc/mysql/mariadb.conf.d/99-openstack.cnf mysqld max_connections 1024
iniset /etc/mysql/mariadb.conf.d/99-openstack.cnf mysqld character-set-server utf8

service mysql restart

wait
# Create needed databases
IFS=. read -ra parts <<< $my_ip && subnet=`echo ${parts[0]}.${parts[1]}.${parts[2]}.%`
echo "Management network:"${subnet}
for db in keystone neutron nova glance cinder; do
  mysql -uroot -p$1 -e "CREATE DATABASE $db;"
  mysql -uroot -p$1 -e "use $db; GRANT ALL PRIVILEGES ON $db.* TO '$db'@'localhost' IDENTIFIED BY '$1';"
  mysql -uroot -p$1 -e "use $db; GRANT ALL PRIVILEGES ON $db.* TO '$db'@'%' IDENTIFIED BY '$1';"
done

mysql -uroot -p$1 -e "CREATE DATABASE nova_api;"
mysql -uroot -p$1 -e "use nova_api; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$1';"
mysql -uroot -p$1 -e "use nova_api; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$1';"

