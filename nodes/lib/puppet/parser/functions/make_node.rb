require 'yaml'
module Puppet::Parser::Functions
  YAMLDIR = '/etc/puppet/node'
  newfunction(:make_node, :type => :rvalue ) do |args|
    nodefile = File.join(YAMLDIR, "#{args[0]}.yml")
      if FileTest.exist?(passfile) && data = YAML.load_file(passfile)
        data['password']
      else
        return ''
      end
  end
end
