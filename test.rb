require 'ipaddr'

prov_network = "10.0.0.0/16"

net = IPAddr.new prov_network
puts net.to_range()
bbb = net.inspect().split("/")[1].split(">")[0]
#bbb = bbb.split("/").split(">")
puts net.to_s

puts net.to_s().split(".").first(3)
#puts net.to_range().max()
puts net.to_range().last(3).first()
puts net.to_range().first(4)[3]

#gateway, db_ip, controller_ip, compute1_ip, compute2_ip = net.to_range().first(6).last(5)
#puts "gateway is #{gateway}"
#puts db_ip
#puts controller_ip
#puts compute1_ip

#end_ip = net.to_range().last()
#puts end_ip
aa = "aaaabbbb" +
     "bbbb" +
     "cccc"
puts aa