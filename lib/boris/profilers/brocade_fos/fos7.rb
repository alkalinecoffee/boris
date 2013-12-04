require 'boris/profilers/brocade_fos_core'

module Boris; module Profilers
  class FOS7 < BrocadeFOSCore
    
    def self.matches_target?(connector)
      return true if connector.values_at('version').join =~ /fabric os.*v7/i
    end
  end
end; end