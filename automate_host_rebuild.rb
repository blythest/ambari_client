#!/usr/bin/env ruby
load 'ambari_client.rb'
require 'byebug'

# Parse command line.

hostname = ARGV[0]
ambari_server = ARGV[1]

# Connect to the Ambari server.
connection = AmbariCluster.new(host: ambari_server, port: 8080, user: "admin", password: "admin")

# Return clusters.
cluster = connection.clusters[0]

# Get a list of components.
components_list = connection.host_components(cluster: cluster, host: hostname)

# Remove each component.
# components_list.each { |c| connection.remove_component(cluster: cluster, host: hostname, component: c)}

# Verify that each component was removed.
new_components_list = connection.host_components(cluster: cluster, host: hostname)
if not new_components_list.empty?
  die("Not totally empty.")
end

# Add each component.
components_list.each do |c|
  connection.add_component(cluster: cluster, host: hostname, component: c)
  # wait for completion.
end

# Verify each component was added.
new_components_list = connection.host_components(cluster: cluster, host: hostname)
if not new_components_list.sort == components_list.sort
  die("Not all components installed properly.")
end

# Inform user that process is complete.
puts "Complete!"
