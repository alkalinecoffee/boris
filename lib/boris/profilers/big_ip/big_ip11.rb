require 'boris/profiler'
require 'boris/profilers/big_ip_core'

module Boris; module Profilers
  class BigIp11 < BigIP
    
    def self.matches_target?(connector)
      return true if connector.values_at('show sys version').join =~ /sys\:\:version/i
    end
  end
end; end