require 'boris/profilers/big_ip_core'

module Boris; module Profilers
  class BigIP10 < BigIP
    
    def self.matches_target?(connector)
      return true if connector.values_at('show sys version').join =~ /version  10/i
    end
  end
end; end