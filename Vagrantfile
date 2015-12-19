# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

if ENV["LEAP"] == 'DEVELOPMENT'
    FileUtils.cp("provisioning/nodes.dev.conf.yml",
        "onvm/conf/nodes.conf.yml")
    FileUtils.cp("provisioning/ids.dev.conf.yml",
        "onvm/conf/ids.conf.yml")
elsif ENV["LEAP"] == 'PRODUCTION'
    FileUtils.cp("provisioning/nodes.conf.yml",
        "onvm/conf/nodes.conf.yml")
    FileUtils.cp("provisioning/ids.conf.yml",
        "onvm/conf/ids.conf.yml")
end

nodes = YAML.load_file("onvm/conf/nodes.conf.yml")
ids = YAML.load_file("onvm/conf/ids.conf.yml")

Vagrant.configure("2") do |config|
  config.vm.box = "tknerr/managed-server-dummy"
  config.ssh.username = ids['username']
  config.ssh.password = ids['password']

  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.synced_folder "onvm", "/onvm", disabled: false, create: true

  lnodes = nodes['ctlnodes']
  if lnodes
    lnodes.each do |key|
      config.vm.define "#{key}" do |node|
        nodekey = nodes['logical2physical'][key]
        node.vm.provider :managed do |managed|
          managed.server = nodes[nodekey]['eth0']
        end

        node.vm.provision "#{key}-install", type: "shell" do |s|
          s.path = "onvm/scripts/install/install-" + key + ".sh"
          s.args = ids['sys_password'] + ' ' + nodes[nodekey]['eth0'] + ' ' + nodes[nodekey]['eth1']
        end
      end
    end
  end

  # compute node setup
  lnodes = nodes['computenodes']
  if lnodes
    lnodes.each do |key|
      config.vm.define "#{key}" do |node|
        node.vm.provider :managed do |managed|
          managed.server = nodes[key]['eth0']
        end

        node.vm.provision "#{key}-install", type: "shell" do |s|
          s.path = "onvm/scripts/install/install-compute.sh"
          s.args = ids['sys_password'] + " " + nodes[key]['eth0'] + " " + nodes[key]['eth1']
        end

        # we will isntall cinder storage on each compute node as well
        node.vm.provision "#{key}-storage-install", type: "shell" do |s|
          s.path = "onvm/scripts/install/install-cinder-storage.sh"
          s.args = ids['sys_password'] + " " + nodes[key]['eth0'] + " " + nodes[key]['eth1']
        end
      end
    end
  end

  # do initial setup to create public and private network
  # all initialization should run on keystone node
  config.vm.define "init-node" do |node|
      node.vm.provider :managed do |managed|
        managed.server = nodes[nodes['logical2physical']['keystone']]['eth0']
      end

      #node.vm.provision "init-node-01", type: "shell" do |s|
      #  s.path = "onvm/scripts/install/init-node-01.sh"
      #  s.args = ids['sys_password'] + " "
      #  s.args += nodes['public_net']['id'] + " "
      #  s.args += nodes['public_net']['start_ip'] + " "
      #  s.args += nodes['public_net']['end_ip'] + " "
      #  s.args += nodes['public_net']['gateway']
      #end

      node.vm.provision "init-node-02", type: "shell" do |s|
        s.path = "onvm/scripts/install/init-node-02.sh"
        s.args = ids['sys_password']
      end
  end
end
