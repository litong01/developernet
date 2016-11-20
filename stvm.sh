#!/usr/bin/env bash

machines=('os-controller' 'os-compute01' 'os-compute02' 'os-compute03')

for key in ${machines[@]}; do
    echo "Shutting down $key"
    #VBoxManage controlvm $key acpipowerbutton
    VBoxManage controlvm $key poweroff
done
