require 'boris/profiler'
require 'boris/profilers/cisco_core'

module Boris; module Profilers
  class CiscoIOS12 < Cisco
    
    def self.matches_target?(connector)
      return true if connector.value_at('show version') =~ /cisco ios.*version 12/i
    end

    def get_operating_system
      super

      @operating_system[:name] = 'Cisco IOS'
      @operating_system[:version] = @version_data[0].scan(/version (.*),/i).join

      @operating_system
    end
    
  end
end; end