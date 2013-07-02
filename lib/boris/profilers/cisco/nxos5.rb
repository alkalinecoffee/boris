require 'boris/profilers/cisco_nxos_core'

module Boris; module Profilers
  class NXOS5 < CiscoNXOSCore
    
    def self.matches_target?(connector)
      return true if connector.value_at("show version | grep -i 'system version'") =~ /version\: 5/i
    end
    
  end
end; end