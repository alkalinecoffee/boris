require 'boris/profiles/windows_core'

module Boris; module Profiles; module Windows
    module Windows2003
      include Windows
      
      def self.matches_target?(active_connection)
        return true if active_connection.value_at('SELECT Name FROM Win32_OperatingSystem')[:name] =~ /2003/
      end
    end
end; end; end