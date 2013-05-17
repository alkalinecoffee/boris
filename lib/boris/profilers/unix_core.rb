require 'boris/profiler'

module Boris; module Profilers
  class UNIX < Base

    def self.connection_type
      Boris::SSHConnector
    end

    def get_file_systems
      super

      file_system_command = %q{df -kl 2>/dev/null | grep ^/ | nawk '{print $1 "|" $2 / 1024 "|" $3 / 1024 "|" $6}'}
      @connector.values_at(file_system_command).each do |file_system|
        h = file_system_template
        file_system = file_system.split('|')

        h[:capacity_mb] = file_system[1].to_i
        h[:file_system] = file_system[0]
        h[:mount_point] = file_system[3]
        h[:used_space_mb] = file_system[2].to_i

        @file_systems << h
      end

      @file_systems
    end

    def get_hardware; super; end
    def get_hosted_shares; super; end
    def get_installed_applications; super; end
    def get_installed_patches; super; end
    def get_installed_services; super; end

    def get_local_user_groups
      super

      user_data = @connector.values_at('cat /etc/passwd | grep -v "^#"')
      group_data = @connector.values_at('cat /etc/group | grep -v "^#"')

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

      @local_user_groups
    end

    def get_network_id
      super

      hostname = @connector.value_at('hostname')
      domain = @connector.value_at('domainname')
      domain = nil if domain =~ /\(none\)/i
      
      if hostname =~ /\./
        hostname = hostname.split('.').shift
        domain = hostname.join('.') if hostname =~ /\./
      end

      @network_id[:hostname] = hostname
      @network_id[:domain] = domain

      @network_id
    end

    def get_network_interfaces; super; end
    def get_operating_system; super; end

    def get_running_processes
      super

      now = DateTime.parse(@connector.value_at('date'))
      process_data = @connector.values_at('ps -eo time,etime,comm | tail +2 | grep -v defunct')
      process_data.each do |process|
        process = process.strip.split

        h = running_process_template

        h[:cpu_time] = process.shift.pad_elapsed_time
        h[:date_started] = DateTime.parse_start_date(now, process.shift)
        h[:command] = process.join(' ')

        @running_processes << h
      end

      @running_processes
    end
  end
end; end
