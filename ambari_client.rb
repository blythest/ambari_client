#!/usr/bin/env ruby
require 'rest_client'
require 'byebug'
require 'yaml'

class AmbariCluster

  private

  def change_service_state(cluster:, service:, state:)
    body = {
      "RequestInfo" => {
        "operation_level" => {
          "level" => "SERVICE",
          "cluster_name" => cluster
        },
        "context" => "Service #{service} transition to #{state.downcase}"
      },
      "ServiceInfo" => {
        "state" => state
      }
    }.to_json

    headers = { "X-Requested-By" => "#{@user}" }

    uri = service(cluster: cluster, service: service)["href"]

    res = RestClient::Request.new(:method => :put, :url => uri, :user => @user, :password => @password, :headers => headers, :payload => body).execute
    return res
  end

  def change_host_component_state(cluster:, host:, component:, state:)
     body = {
      "RequestInfo" => {
        "operation_level" => {
          "level" => "HOST_COMPONENT",
          "cluster_name" => cluster,
          "host_names" => host
        },
        "context" => "Component #{component} transition to #{state.downcase}"
      },
      "HostRoles" => {
        "state" => state
      }
    }.to_json

    headers = { "X-Requested-By" => "#{@user}" }

    uri = host_component(cluster: cluster, host: host, component: component)["href"]

    res = RestClient::Request.new(:method => :put, :url => uri, :user => @user, :password => @password, :headers => headers, :payload => body).execute
    return res
  end

  public

  def initialize(host:, port:, user:, password:)
    @host     = host
    @port     = port
    @user     = user
    @password = password

    @uri = "http://#{@user}:#{@password}@#{@host}:#{port}/api/v1/"

    @test_cluster = { "c1" => { }, "c2" => {} }
  end

  def clusters
    # Fetch a list of clusters this ambari server manages
    # returns an array
    res = JSON(RestClient.get(@uri + "clusters/"))
    clusters = res['items'].collect { |item| item["Clusters"]["cluster_name"] }
    return clusters
  end

  def cluster(cluster:)
    # Fetch a JSON object describing the named cluster
    res = JSON(RestClient.get(@uri + "clusters/#{cluster}"))
    return res
  end

  def hosts(cluster:)
    # Fetch a list of hosts within a named cluster
    # returns an array
    res = JSON(RestClient.get(@uri + "clusters/#{cluster}/hosts/"))
    hosts = res['items'].collect { |item| item["Hosts"]["host_name"] }
    return hosts
  end

  def host(cluster:, host:)
    # Fetch a JSON object describing the named host
    res = JSON(RestClient.get(@uri + "clusters/#{cluster}/hosts/#{host}/"))
    return res
  end

  def services(cluster:)
    # Fetch a list of services within a named cluster
    res = JSON(RestClient.get(@uri + "clusters/#{cluster}/services/"))
    services = res['items'].collect { |item| item["ServiceInfo"]["service_name"] }
    return services
  end

  def service(cluster:, service:)
    # Fetch a JSON object describing the names service
    res = JSON(RestClient.get(@uri + "clusters/#{cluster}/services/#{service}"))
    return res
  end

  def service_components(cluster:, service:)
    # Fetch a list of components within a named service
    res = JSON(RestClient.get(@uri + "clusters/#{cluster}/services/#{service}/components/"))

    components = res['items'].collect { |item| item["ServiceComponentInfo"]["component_name"] }
    return components
  end

  def service_component(cluster:, service:, component:)
    # Fetch a JSON object describing a service component
    res = JSON(RestClient.get(@uri + "clusters/#{cluster}/services/#{service}/components/#{component}/"))
    return res
  end

  def host_components(cluster:, host:)
    # Return a list of components running on the host
    res = JSON(RestClient.get(@uri + "clusters/#{cluster}/hosts/#{host}/host_components/"))

    components = res['items'].collect { |item| item["HostRoles"]["component_name"] }
  end

  def host_component(cluster:, host:, component:)
    # Fetch a JSON object describing a component on a host
    res = JSON(RestClient.get(@uri + "clusters/#{cluster}/hosts/#{host}/host_components/#{component}"))
    return res
  end

  def start_service(cluster:, service:)
    res = change_service_state(cluster: cluster, service: service, state: "STARTED")
    return res
  end

  def stop_service(cluster:, service:)
    res = change_service_state(cluster: cluster, service: service, state: "INSTALLED")
    return res

  end

  def start_component(cluster:, host:, component:)
    res = change_host_component_state(cluster: cluster, host: host, component: component, state: "STARTED")
    return res
  end

  def stop_component(cluster:, host:, component:)
    res = change_host_component_state(cluster: cluster, host: host, component: component, state: "INSTALLED")
    return res
  end

  def add_service_component(cluster:, service:, component:)
    # a new component is installed by first doing a POST to the endpoint to place it in install_pending
    headers = { "X-Requested-By" => "#{@user}" }
    uri = @uri + "clusters/#{cluster}/services/#{service}/components/#{component}"
    RestClient::Request.new(:method => :post, :url => uri, :user => @user, :password => @password, :headers => headers).execute
  end


  def add_service(cluster:, service:)
    headers = { "X-Requested-By" => "#{@user}" }
    if services(cluster: cluster).include?(service)
      puts "already installed."
    else
      uri = @uri + "clusters/#{cluster}/services/#{service}"
      RestClient::Request.new(:method => :post, :url => uri, :user => @user, :password => @password, :headers => headers).execute
      components = YAML.load_file("components.yml")[0]["service_components"]
      components[service].each do |component|
        add_service_component(cluster: cluster, service: service, component: component)
      end
    end
  end

  def remove_service(cluster:, service:)
    headers = { "X-Requested-By" => "#{@user}" }
    service_name = service(cluster:cluster, service:service)
    uri = service_name["href"]
    RestClient::Request.new(:method => :delete, :url => uri, :user => @user, :password => @password, :headers => headers).execute
  end

  def add_component(cluster:, host:, component:)
    # a new component is installed by first doing a POST to the endpoint to place it in install_pending
    # and then following it with a state change to INSTALLED (which just so happens is what the stop method does)
    headers = { "X-Requested-By" => "#{@user}" }
    uri = host(cluster: cluster, host: host)['href'] + "host_components/#{component}"
    RestClient::Request.new(:method => :post, :url => uri, :user => @user, :password => @password, :headers => headers).execute
    res = stop_component(cluster: cluster, host: host, component: component)
  end

  def remove_component(cluster:, host:, component:)
    headers = { "X-Requested-By" => "#{@user}" }
    uri = host_component(cluster: cluster, host: host, component: component)['href']
    return RestClient::Request.new(:method => :delete, :url => uri, :user => @user, :password => @password, :headers => headers).execute
  end

  def add_host(cluster:, host:)
    headers = { "X-Requested-By" => "#{@user}"}
    return if hosts(cluster: cluster)['href']
        RestClient::Request.new(:method => :post, :url => uri, :user => @user, :password => @password, :headers => headers).execute
    end
  end

  def remove_host(cluster:, host:)
    headers = { "X-Requested-By" => "#{@user}" }
    uri = host(cluster: cluster, host: host)['href']
    RestClient::Request.new(:method => :delete, :url => uri, :user => @user, :password => @password, :headers => headers).execute
  end
