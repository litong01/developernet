require 'yaml'

nodes = YAML.load_file("provisioning/nodes.dev.conf.yml")
ids = YAML.load_file("provisioning/ids.dev.conf.yml")

puts nodes['network']
puts nodes['synchfolders'][nodes['network']]['folder']
if nodes['synchfolders'][nodes['network']]['nodes'].index('mysqldb')
  puts 'hi'
else
  puts 'cooo'
end

syncednodes = nodes['synchfolders']['ovs']['nodes']
puts syncednodes
bb = syncednodes.index('controller')
if bb
  puts bb, ' is'
  syncednodes = syncednodes.delete(bb)
else
  puts bb, 'not'
end
puts syncednodes


initfiles = Dir["onvm/scripts/install/init-node-[0-9][0-9].sh"]
initfiles.each do | filepath |
   puts filepath
   pname = File.basename(filepath, ".*")
   puts pname
   netinitfiles = Dir["onvm/scripts/install/" + pname + "-ovn.sh"]
   if netinitfiles.length > 0
      filepath = netinitfiles[0]
      puts "hahahaha " + filepath
   end
end