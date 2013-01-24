require 'boris/profiles/windows_core'

module Boris; module Profiles; module Windows
    module Windows2008
      include Windows

      def self.connection_type
        Windows.connection_type
      end
      
      def self.matches_target?(connector)
        return true if connector.value_at('SELECT Name FROM Win32_OperatingSystem')[:name] =~ /2008/
      end

      def get_operating_system
        super

        # grab the 'features' from win2008 servers, as it's only available on this version
        # and already deprecated as of win2012
        @operating_system[:features] = @connector.values_at('SELECT Name FROM Win32_ServerFeature').map {|f| f[:name]}
      end
    end
end; end; end