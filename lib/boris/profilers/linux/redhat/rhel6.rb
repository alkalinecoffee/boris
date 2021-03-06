require 'boris/profilers/linux/redhat_core'

module Boris; module Profilers
  class RHEL6 < RedHatCore
    
    def self.matches_target?(connector)
      release_data = connector.values_at(%q{ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb|system"}).join(' ')
      if release_data =~ /redhat-release/i && connector.value_at('cat /etc/redhat-release') =~ /release 6\./
        return true
      end
    end
  end
end; end