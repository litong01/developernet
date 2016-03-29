#!/usr/bin/env bash

echo "Setting security rules for demo project..."

source ~/demo-openrc.sh

neutron security-group-rule-create --direction ingress --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
neutron security-group-rule-create --direction egress --protocol icmp --remote-ip-prefix 0.0.0.0/0 default

neutron security-group-rule-create --direction ingress --protocol tcp \
  --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default

echo "Ini-node-03 is now complete!"
