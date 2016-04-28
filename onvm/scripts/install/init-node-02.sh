#!/usr/bin/env bash
# $1 sys_password
# $2 public net id
# $3 public net start_ip
# $4 public net end_ip
# $5 public net gateway

echo "Setting image..."

source ~/admin-openrc.sh
export OS_IMAGE_API_VERSION=2

if [ ! -f /leapbin/cirros-0.3.4-x86_64-disk.img ];then
  echo "Downloading cirros cloud image..."
  wget -nv -P /leapbin http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
fi

glance image-create --name "cirros" \
  --file /leapbin/cirros-0.3.4-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --visibility public

echo "Init-node-02 is now complete!"
