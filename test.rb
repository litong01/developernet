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

syncednodes = []
syncednodes.index('whatever')
syncednodes.push('aaaa')
