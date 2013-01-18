require 'boris/structure'

module Boris; module Profiles
  module UNIX
    include Structure

    def self.matches_target?(active_connection)
      return true if active_connection.value_at('uname -a') !~ /linux/i
    end

    def get_file_systems
      super

      file_system_command = %q{df -kl 2>/dev/null | grep ^/ | nawk '{print $1 "|" $2 / 1024 "|" $3 / 1024 "|" $6}'}
      @active_connection.values_at(file_system_command).each do |file_system|
        h = file_system_template
        file_system = file_system.split('|')

        h[:capacity_mb] = file_system[1].to_i
        h[:file_system] = file_system[0]
        h[:mount_point] = file_system[3]
        h[:used_space_mb] = file_system[2].to_i

        @file_systems << h
      end
    end

    def get_hardware; super; end
    def get_hosted_shares; super; end
    def get_installed_applications; super; end
    def get_installed_patches; super; end
    def get_installed_services; super; end

    def get_local_user_groups
      super

      user_data = @active_connection.values_at('cat /etc/passwd')
      group_data = @active_connection.values_at('cat /etc/group')

      users = []
      groups = []

      user_data.each do |x|
        h = {}
        x = x.split(':')
        h[:status] = nil
        h[:primary_group_id] = x[3]
        h[:username] = x[0]
        users << h
      end

      group_data.each do |group|
        group = group.split(':')
        h = {:members=>[], :name=>group[0]}

        h[:members] = users.select{|user| (user[:primary_group_id] == group[2])}.collect{|user| user[:username]}
        
        @local_user_groups << h
      end
    end

    def get_network_id
      super

      hostname = @active_connection.value_at('hostname')
      domain = @active_connection.value_at('domainname')
      domain = nil if domain =~ /\(none\)/i
      
      if hostname =~ /\./
        hostname = hostname.split('.').shift
        domain = hostname.join('.')
      end

      @network_id[:hostname] = hostname
      @network_id[:domain] = domain
    end

    def get_network_interfaces; super; end
    def get_operating_system; super; end
  end
end; end
