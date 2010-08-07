#! /usr/bin/ruby

#
# A function to lookup virtual machines from the dashboard. 
#

require 'yaml'
require 'uri'
require 'net/http'
BASE="http://localhost:3000"

def hash2resource(scope, hash)
  unless type = hash["type"]
    raise ArgumentError, "Must provide type as a hash attribute when creating a resource"
  end
  unless title = hash["title"]
    raise ArgumentError, "Must provide title as a hash attribute when creating a resource"
  end
  resource = Puppet::Parser::Resource.new(:scope => scope, :type => type, :title => title, :source => @main)
  hash.each do |param, value|
    resource.set_parameter(param, value) unless %w{type title}.include?(param)
  end
  resource
end

def create_resource_from_hash(scope, hash)
  resource = hash2resource(scope, hash)
  scope.compiler.add_resource(scope, resource)
end

def connect_to_dashboard()
  Puppet[:config] = "/etc/puppet/puppet.conf"
  Puppet.parse_config
  cert = File.read(Puppet[:hostcert])
  pem = File.read(Puppet[:hostprivkey])
  ca = Puppet[:localcacert]
  @dashboard_ssl = Net::HTTP.new(@dashboard_host, @dashboard_port)
  @dashboard_ssl.use_ssl = true
  @dashboard_ssl.cert = OpenSSL::X509::Certificate.new(cert)
  @dashboard_ssl.key = OpenSSL::PKey::RSA.new(pem)
  @dashboard_ssl.ca_file = ca
  @dashboard_ssl.verify_mode = OpenSSL::SSL::VERIFY_PEER
end

def get_yaml_from_dashboard(node_name)
  connect_to_dashboard()  unless @dashboard_ssl
  res = @dashboard_ssl.start { @dashboard_ssl.request_get("/nodes/#{node_name}", 'Accept' => 'text/yaml')}
  YAML::load(res.body)
end

def get_virtual_from_physical(physical_node_yaml)
  virtual_node_yaml = {}
  physical_node_yaml['parameters'].each do |parameter, value|
    if parameter =~ /virtnode::*/
      function_notice(["Found virtualnode #{value}"])
      virtual_node_yaml[value] = get_yaml_from_dashboard(value)
    end
  end
  return virtual_node_yaml
end

def virtual_node_yaml_to_resource(virtual_node_yaml)
  virtual_node_yaml.each do |nodename, nodedata|
    function_notice(["Creating virtualnode resource: #{nodename}"])
    params = nodedata['parameters']
    vparams = {}
    params.each do |key, value| 
      if key =~ /virtnode::*/
        vparams["#{key.split('::')[1]}"] = value
      end
    end
    vparams['title'] = params['virtnode::id']
    vparams.delete('id')
    vparams['hostname'] = nodename
    vparams.each do |key, value|
      function_notice(["#{key} => #{value}"])
    end
    create_resource_from_hash self,vparams
  end
end

module Puppet::Parser::Functions
  newfunction(:virtnodes) do |args| 
    #
    # This should be determinable from the puppet.conf options.
    #
    @dashboard_host = args[0]
    @dashboard_port = args[1]
    #
    # Node name must be the certname
    #
    @node_name = args[2] 
    function_notice(["Searching for nodes assigned to #{@node_name}"])
    physical_node_yaml = get_yaml_from_dashboard(@node_name)
    virtual_node_yaml = get_virtual_from_physical(physical_node_yaml) 
    virtual_node_yaml_to_resource(virtual_node_yaml)
  end
end
