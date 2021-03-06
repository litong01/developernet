#!/usr/bin/env bash
export LEAP=DEVELOPMENT
export VAGRANT_VAGRANTFILE="Vagrantfile"
rm -r -f .vagrant

machines=('os-controller' 'os-compute01' 'os-compute02' 'os-compute03')
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
