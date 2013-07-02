require 'boris/profilers/onboard_administrator_core'

module Boris; module Profilers
  class OA3 < OnboardAdministratorCore
    
    def self.matches_target?(connector)
      return true if connector.values_at('show fru').join =~ /firmware version: 3/i
    end
  end
end; end