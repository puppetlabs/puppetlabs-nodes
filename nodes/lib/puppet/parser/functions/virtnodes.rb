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

def get_yaml_from_dashboard(node_name)
  url = URI.parse("#{BASE}/nodes/#{node_name}")
  req = Net::HTTP::Get.new(url.path, 'Accept' => 'text/yaml')
  res = Net::HTTP.start(url.host, url.port) {|http| http.request(req) }
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
  newfunction(:virtnodes) do 
    node_name = lookupvar('fqdn')
    function_notice(["Searching for nodes assigned to #{node_name}"])
    physical_node_yaml = get_yaml_from_dashboard(node_name)
    virtual_node_yaml = get_virtual_from_physical(physical_node_yaml) 
    virtual_node_yaml_to_resource(virtual_node_yaml)
  end
end
