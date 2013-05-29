require 'boris/profilers/unix/solaris_core'

module Boris; module Profilers
  class Solaris10 < SolarisCore
    
    def self.matches_target?(connector)
      release_data = connector.value_at('uname -a')
      return true if release_data =~ /sunos.+5\.10/i
    end
  end
end; end