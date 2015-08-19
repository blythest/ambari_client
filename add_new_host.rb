#!/usr/bin/env ruby
load 'ambari_client.rb'
require 'yaml'
require 'byebug'

cluster_name = ARGV[0]
datanode = ARGV[1]

node_attr = YAML.load_file('cluster.yml')[0]
connection = node_attributes['ambari_server']
new_node = connection.add_host(cluster: node_attr['cluster'], components: node_attr['datanode'])



