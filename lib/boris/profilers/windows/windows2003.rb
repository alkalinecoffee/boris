require 'boris/profilers/windows_core'

module Boris; module Profilers
  class Windows2003 < WindowsCore
    
    def self.matches_target?(connector)
      return true if connector.value_at('SELECT Name FROM Win32_OperatingSystem')[:name] =~ /2003/
    end
  end
end; end