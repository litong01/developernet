#!/usr/bin/env bash

rm -r -f .vagrant

machines=('os-controller' 'os-neutron' 'os-compute01' 'os-compute02')
snapshot=${1:-"Snapshot 2"}

for key in ${machines[@]}; do
    echo "Restore snapshot '$snapshot' for $key"
    VBoxManage snapshot $key restore "$snapshot"
done

for key in ${machines[@]}; do
    echo "Starting up $key"
    VBoxManage startvm $key --type headless
done

vagrant up