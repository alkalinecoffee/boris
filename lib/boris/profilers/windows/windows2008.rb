require 'boris/profilers/windows_core'

module Boris; module Profilers
  class Windows2008 < WindowsCore

    def self.matches_target?(connector)
      return true if connector.value_at('SELECT Name FROM Win32_OperatingSystem')[:name] =~ /2008/
    end

    def get_operating_system
      super
      get_operating_system_features
    end

    private

    def get_operating_system_features
      # grab the 'features' from win2008 servers, as it's only available on this version
      # and already deprecated as of win2012
      @operating_system[:features] = @connector.values_at('SELECT Name FROM Win32_ServerFeature').map {|f| f[:name]}

      @operating_system
    end
  end
end; end