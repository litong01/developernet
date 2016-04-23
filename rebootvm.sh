rm -r -f .vagrant
VBoxManage snapshot os-controller restore "Snapshot 2"
VBoxManage snapshot os-neutron restore "Snapshot 2"
VBoxManage snapshot os-compute01 restore "Snapshot 2"
VBoxManage snapshot os-compute02 restore "Snapshot 2"

vboxmanage startvm os-controller --type headless
vboxmanage startvm os-neutron --type headless
vboxmanage startvm os-compute01 --type headless
vboxmanage startvm os-compute02 --type headless

vagrant up