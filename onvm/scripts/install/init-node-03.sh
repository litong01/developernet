#!/usr/bin/env bash

echo "Setting security rules for demo project..."

source ~/admin-openrc.sh

echo "Creating flavors..."
openstack flavor create --public m1.tiny --id 101 --ram 512 --disk 1 --vcpus 1 --rxtx-factor 1
openstack flavor create --public m1.small --id 102 --ram 1024 --disk 2 --vcpus 1 --rxtx-factor 1
openstack flavor create --public m1.medium --id 103 --ram 2048 --disk 4 --vcpus 1 --rxtx-factor 1

source ~/demo-openrc.sh

neutron security-group-rule-create --direction ingress --protocol icmp --remote-ip-prefix 0.0.0.0/0 default
neutron security-group-rule-create --direction egress --protocol icmp --remote-ip-prefix 0.0.0.0/0 default

neutron security-group-rule-create --direction ingress --protocol tcp \
  --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0 default

echo "Init-node-03 is now complete!"
