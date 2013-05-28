require 'boris/profilers/cisco_core'

module Boris; module Profilers
  class IOS12 < Cisco
    
    def self.matches_target?(connector)
      version = connector.values_at('show version | include (Version|ROM)')
      return true if version[0] =~ /cisco ios.*version 12/i && version.join =~ /ROM:\s+12/i
    end

    def get_operating_system
      super

      @operating_system[:name] = 'Cisco IOS'
      @operating_system[:version] = version_data[0].extract(/version (.*),/i)

      @operating_system
    end
    
  end
end; end