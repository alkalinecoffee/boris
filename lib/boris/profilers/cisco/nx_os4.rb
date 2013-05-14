require 'boris/profiler'
require 'boris/profilers/cisco_core'

module Boris; module Profilers
  class CiscoNXOS4 < Cisco
    
    def self.matches_target?(connector)
      return true if connector.value_at('show version') =~ /cisco nexus/i
    end

    def get_operating_system
      super

      @operating_system[:name] = 'Cisco Nexus'
      @operating_system[:version] = @version_data.grep(/kickstart/i)[0].scan(/version (.*)/i).join

      @operating_system
    end
    
  end
end; end