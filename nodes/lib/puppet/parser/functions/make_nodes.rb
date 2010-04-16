require 'yaml'

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

module Puppet::Parser::Functions
  newfunction(:make_nodes) do |args|
    YAMLDIR = args[0]
    Dir.glob("#{YAMLDIR}/*yml").each do |nodefile| 
      if FileTest.exist?(nodefile) && data = YAML.load_file(nodefile)
        data['title'] = File.basename(nodefile, ".yml")
        create_resource_from_hash self,data
      end
    end
  end
end
