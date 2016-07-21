#!/usr/bin/env bash
# $1 sys_password
# $2 public ip eth0
# $3 private ip eth1

#source /onvm/scripts/ini-config
#eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

function get_id {
  local cmdstr=$1
  local findstr=$2
  local idindex=$3
  local an_id
  tempstr=$( $cmdstr | grep "$findstr" | head -n 1 )
  IFS='|' read -r -a tempstr <<< $tempstr
  an_id=$( echo "${tempstr[$idindex]}" | xargs )
  echo $an_id
}

source ~/demo-openrc.sh

controller_image_id=$( get_id 'glance image-list' 'base' 1 )
compute_image_id=$( get_id 'glance image-list' 'base' 1 )

private_net_id=$( get_id 'neutron net-list' 'dojo-private' 1 )
public_net_id=$( get_id 'neutron net-list' 'dojo-public' 1 )
flavor_small=$( get_id 'nova flavor-list' 'm1.small' 1 )
flavor_medium=$( get_id 'nova flavor-list' 'm1.medium' 1 )

nova boot --flavor=$flavor_small --image=$controller_image_id \
  --nic net-id=$public_net_id,v4-fixed-ip=172.16.2.10 \
  --nic net-id=$private_net_id,v4-fixed-ip=172.16.31.10 \
  dojo-controller

nova boot --flavor=$flavor_medium --image=$compute_image_id \
  --nic net-id=$public_net_id,v4-fixed-ip=172.16.2.11 \
  --nic net-id=$private_net_id,v4-fixed-ip=172.16.31.11 \
  dojo-compute
