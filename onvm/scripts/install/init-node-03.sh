#!/usr/bin/env bash
# $1 sys_password
# $2 public net id
# $3 public net start_ip
# $4 public net end_ip
# $5 public net gateway

source /onvm/scripts/ini-config
eval $(parse_yaml '/onvm/conf/nodes.conf.yml' 'leap_')

if [ "$leap_network" != 'ovn' ]; then
  echo "Setting security rules for demo project..."

  source ~/demo-openrc.sh

  neutron security-group-rule-create --direction ingress --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
  neutron security-group-rule-create --direction egress --protocol icmp --remote-ip-prefix 0.0.0.0/0 default

  neutron security-group-rule-create --direction ingress --protocol tcp \
    --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default
fi

echo "Init-node-03 is now complete!"
