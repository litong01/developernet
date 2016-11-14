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

  n_type = nodes['network']
  suffixes = nodes['suffixes']

  sync_cfg = nodes['synchfolders'][n_type]

  lnodes = nodes['ctlnodes']
  if lnodes
    lnodes.each do | key |
      suffix = suffixes.index(key)? ('-' + n_type):''
      pnodes = nodes['logical2physical'][key]
      if not pnodes.instance_of? Array
        pnodes = [].push(pnodes)
      end
      pnodes.each do | pnode |
        vmname = (pnodes.length > 1)? "#{key}-#{pnode}":"#{key}"
        config.vm.define "#{vmname}" do |node|
          node.vm.hostname = "#{vmname}"

          if sync_cfg['nodes'].index(key)
            node.vm.synced_folder sync_cfg['folder'], "/leapbin", disabled: false, create: true
          end

          node.vm.provider :managed do |managed|
            managed.server = nodes[pnode]['eth0']
          end

          node.vm.provision "#{key}-install", type: "shell" do |s|
            s.path = "onvm/scripts/install/install-" + key + suffix + ".sh"
            s.args = ids['sys_password'] + ' ' + nodes[pnode]['eth0'] + ' ' + nodes[pnode]['eth1']
          end
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

    initfiles = Dir["onvm/scripts/install/init-node-[0-9][0-9].sh"]
    initfiles.each do | filepath |
      pname = File.basename(filepath, ".*")
      netinitfiles = Dir["onvm/scripts/install/" + pname + "-" + n_type + ".sh"]
      if netinitfiles.length > 0
        filepath = netinitfiles[0]
      end

      node.vm.provision "#{pname}", type: "shell" do |s|
        s.path = filepath
      end
    end
  end

end
