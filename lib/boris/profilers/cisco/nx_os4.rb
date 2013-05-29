require 'boris/profilers/cisco_core'

module Boris; module Profilers
  class NXOS4 < CiscoCore
    
    def self.matches_target?(connector)
      return true if connector.values_at('show version') =~ /cisco nexus/i
    end

    def get_operating_system
      super

      get_version_data

      @operating_system[:name] = 'Cisco Nexus'
      @operating_system[:version] = @version_data.grep(/kickstart/i)[0].extract(/version (.*)/i)

      @operating_system
    end
    
  end
end; end