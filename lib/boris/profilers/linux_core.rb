require 'boris/profiler'

module Boris; module Profilers
  class Linux < Profiler

    def self.connection_type
      Boris::SSHConnector
    end

    def get_file_systems
      super

      file_system_command = %q{df -P -T | grep "^/" | awk '{print $1 "|" $3 / 1024 "|" $5 / 1024 "|" $7}'}
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

    def get_hardware
      super

      cpu_arch_data = @connector.value_at('uname -m')
      @hardware[:cpu_architecture] = cpu_arch_data =~ /ia|_(64)/ ? 64 : 32

      cpu_data = @connector.values_at('cat /proc/cpuinfo | egrep -i "processor|vendor|mhz|name|cores"')
      @hardware[:cpu_physical_count] = cpu_data.grep(/processor/i).last.after_colon.to_i + 1
      @hardware[:cpu_model] = cpu_data.grep(/model name/i)[0].after_colon
      @hardware[:cpu_vendor] = cpu_data.grep(/vendor_id/i)[0].after_colon
      @hardware[:cpu_speed_mhz] = cpu_data.grep(/cpu mhz/i)[0].after_pipe.to_i

      # cpu cores aren't always displayed via /proc/cpuinfo
      cpu_cores = cpu_data.grep(/cpu cores/i)[0]
      @hardware[:cpu_core_count] = cpu_cores.after_colon.to_i if cpu_cores

      memory_data = @connector.value_at("cat /proc/meminfo | grep -i memtotal | awk '{print $2 / 1024}'")
      @hardware[:memory_installed_mb] = memory_data.to_i

      hardware_data = @connector.values_at('/usr/bin/sudo /usr/sbin/dmidecode -t 0,1,4', true)

      if hardware_data.any?
        # grab the cpu speed again (because its value is usually more useful/relevant than that found via /proc/cpuinfo)
        @hardware[:cpu_speed_mhz] = hardware_data.grep(/current speed/i)[0].after_colon.extract(/(\d+)/).to_i
        @hardware[:firmware_version] = hardware_data.grep(/version/i)[0].after_colon
        @hardware[:model] = hardware_data.grep(/product name/i)[0].after_colon
        @hardware[:serial] = hardware_data.grep(/serial number/i)[0].after_colon
        @hardware[:vendor] = hardware_data.grep(/manufacturer/i)[0].after_colon
      else
        info 'no hardware information available (give me sudo access for dmidecode!)'
      end

      @hardware
    end

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

      hostname = @connector.value_at('hostname').split('.')
      @network_id[:hostname] = hostname.shift

      domain = @connector.value_at('domainname')
      domain = nil if domain =~ /\(none\)/i

      @network_id[:domain] = domain.nil? ? hostname.join('.') : domain

      @network_id
    end

    def get_network_interfaces
      super

      # grab the make/model/slot info for all ethernet/fc ports
      ports = @connector.values_at('/sbin/lspci -mmv | egrep -i "class:[[:space:]]*(ethernet controller|fibre channel)" -B1 -A5')

      ## ETHERNET
      # get some basic info that will apply to all ethernet interfaces
      dns_servers = @connector.values_at("cat /etc/resolv.conf | grep ^nameserver | awk '{print $2}'")

      found_ethernet_interfaces = ports.join("\n").split('--').grep(/ethernet controller/i)
      found_fibre_interfaces = ports.join("\n").split('--').grep(/fibre channel/i)

      if found_ethernet_interfaces.any?
        # get info on all ethernet interfaces
        ethernet_mapping_data = @connector.values_at(%q{ls /sys/class/net | awk '{cmd="readlink -f /sys/class/net/" $1 "/device/"; cmd | getline link; print $1 "|" link}'})
        link_properties = @connector.values_at(%q{find -L /sys/class/net/ -mindepth 2 -maxdepth 2 2>/dev/null | awk '{cmd = "cat " $0 " 2>/dev/null"; cmd | getline value; print $0 "|" value;}'})
        ip_addr_data = @connector.values_at(%q{/sbin/ip addr | awk '{if($0 ~ /^[0-9]:/) {print "\n" $0} else {print $0}}'})

        found_ethernet_interfaces.each do |interface|
          interface = interface.split("\n")
          
          h = network_interface_template

          h[:dns_servers] = dns_servers
          h[:type] = 'ethernet'

          h[:model] = interface.grep(/^.*sdevice:/i)[0].after_colon
          h[:vendor] = interface.grep(/^.*svendor:/i)[0].after_colon
          
          pci_slot = interface.grep(/^.*slot:/i)[0].after_colon

          h[:name] = ethernet_mapping_data.grep(/#{pci_slot}$/)[0].before_pipe

          interface_config = link_properties.grep(/\/#{h[:name]}\//)

          h[:mac_address] = interface_config.grep(/\/address\|/)[0].after_pipe.upcase

          # operstate sometimes gives reports interface as 'unknown' when it is up
          # and working.  checking the value of carrier (0 for not plugged in, 1 for
          # plugged in) in conjunction with the 'ip' command output is a good fallback
          wired_connection = interface_config.grep(/\/carrier\|/)[0].after_pipe
          
          ip_config = ip_addr_data.join("\n").strip.split(/\n\n/).grep(/^.*:\s#{h[:name]}:/)[0].split(/\n/)

          h[:status] = (ip_config[0] =~ /,up,/i && wired_connection =~ /1/i) ? 'up' : 'down'

          if h[:status] == 'up'
            # speed & duplex are not always available (in case of a virtual machine
            # or hardware failure, etc)
            speed = interface_config.grep(/\/speed\|/)[0]
            h[:current_speed_mbps] = speed.after_pipe.to_i if speed

            duplex = interface_config.grep(/\/duplex\|/)[0]
            h[:duplex] = duplex.after_pipe if duplex
            
            h[:mtu] = interface_config.grep(/\/mtu\|/)[0].after_pipe.to_i

            ip_config.grep(/^.*inet /).each do |ip|
              ip_address = ip.split[1].before_slash
              netmask_bits = ip.split[1].after_slash
              h[:ip_addresses] << {:ip_address=>ip_address, :subnet=>NetAddr.i_to_ip(NetAddr.netmask_to_i(netmask_bits))}
            end
          end

          @network_interfaces << h
        end
      end

      if found_fibre_interfaces.any?
        fibre_mapping_data = @connector.values_at("find /sys/devices/pci* -regex '.*fc_host/host[0-9]'")
        interface_config = @connector.values_at(%q{find -L /sys/class/fc_host/ -mindepth 2 -maxdepth 2 | awk '{value=""; "cat " $1 " 2>/dev/null" | getline value; print $1 "|" value;}'})

        found_fibre_interfaces.each do |interface|
          interface = interface.split("\n")

          h = network_interface_template

          h[:type] = 'fibre'

          h[:model] = interface.grep(/^.*device:/i)[0].after_colon
          h[:vendor] = interface.grep(/^.*vendor:/i)[0].after_colon
          
          pci_slot = interface.grep(/^.*slot:/i)[0].split[1]

          h[:name] = fibre_mapping_data.grep(/0000:#{pci_slot}\//)[0].after_slash

          interface_config = interface_config.grep(/fc_host\/#{h[:name]}\//)

          status = interface_config.grep(/\/port_state\|/)[0].after_pipe
          h[:status] = status =~ /online/i ? 'up' : 'down'

          if h[:status] == 'up'
            speed = interface_config.grep(/\/speed\|/)[0].after_pipe.split
            h[:current_speed_mbps] = speed[0].to_i * 1000
            h[:fabric_name] = interface_config.grep(/\/fabric_name\|/)[0].after_pipe.sub(/^0x/, '')
            h[:node_wwn] = interface_config.grep(/\/node_name\|/)[0].after_pipe.sub(/^0x/, '')
            h[:port_wwn] = interface_config.grep(/\/port_name\|/)[0].after_pipe.sub(/^0x/, '')
          end

          @network_interfaces << h
        end
      end

      @network_interfaces
    end

    def get_operating_system; super; end

    def get_running_processes
      super

      now = DateTime.parse(@connector.value_at('date'))
      process_data = @connector.values_at('ps -eo time,etime,comm | tail -n +2 | grep -v defunct')
      process_data.each do |process|
        process = process.split

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
