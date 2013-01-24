require 'boris/profiles/windows_core'

module Boris; module Profiles; module Windows
    module Windows2012
      include Windows

      def self.connection_type
        Windows.connection_type
      end
      
      def self.matches_target?(connector)
        return true if connector.value_at('SELECT Name FROM Win32_OperatingSystem')[:name] =~ /2012/
      end
    end
end; end; end