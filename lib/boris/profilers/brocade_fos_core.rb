require 'boris/profiler_core'

module Boris; module Profilers
  class BrocadeFOS
    include ProfilerCore
    
    def self.connection_type
      Boris::SSHConnector
    end

    def switchshow_data
      @switchshow_data ||= @connector.values_at('switchshow')
    end

    def version_data
      @version_data ||= @connector.values_at('version')
    end

    def get_file_systems; super; end

    def get_hardware
      super

      switch_type_id = switchshow_data.grep(/switchtype/i)[0].after_colon.extract(/(\d+)\./).to_i

      @hardware[:firmware_version] = version_data.grep(/bootprom/i)[0].after_colon

      @hardware[:model] = CODE_LOOKUPS['brocade']['switches'][switch_type_id]

      serial = @connector.value_at('chassisshow | grep "Factory Serial"')
      @hardware[:serial] = serial.after_colon.strip.upcase

      @hardware[:vendor] = VENDOR_BROCADE

      @hardware
    end

    def get_hosted_shares; super; end
    def get_installed_applications; super; end
    def get_installed_patches; super; end
    def get_installed_services; super; end
    def get_local_user_groups; super; end
    
    def get_network_id
      super

      hostname = switchshow_data.grep(/switchname/i)[0].after_colon.split('.')

      @network_id[:hostname] = hostname.shift
      @network_id[:domain] = hostname.join('.') if hostname.any?

      @network_id
    end
    
    def get_network_interfaces
      super

      # get the management (ethernet) port... usually eth0
      ifmodeshow_data = @connector.values_at('ifmodeshow "eth0"')

      if ifmodeshow_data.join =~ /mac address/i
        h = network_interface_template

        link_data = ifmodeshow_data.grep(/link mode/i)[0].after_colon

        h[:auto_negotiate] = link_data =~ /negotiated/i ? true : false
        h[:mac_address] = ifmodeshow_data.grep(/mac address/i)[0].split.last.upcase
        h[:model] = 'Unknown Ethernet Adapter'
        h[:name] = 'eth0'
        h[:status] = link_data =~ /link ok/i ? 'up' : 'down'
        h[:type] = 'ethernet'
        h[:vendor] = VENDOR_BROCADE

        if h[:status] == 'up'
          h[:current_speed_mbps] = link_data.extract(/(\d+)base/i).to_i

          ip_data = @connector.values_at('ipaddrshow')

          h[:ip_addresses] << {
            :ip_address=>ip_data.grep(/ethernet ip address/i)[0].after_colon,
            :subnet=>ip_data.grep(/ethernet subnet/i)[0].after_colon
          }
        end

        @network_interfaces << h
      end

      # now get the fibre ports
      # first we have determine whether the data from the switchshow command includes slot numbers
      offset = switchshow_data.grep(/media.*speed.*state/i)[0] =~ /slot/i ? 1 : 0

      switch_ports = switchshow_data.join("\n").split(/\=+/).last.strip.split(/\n/) unless switchshow_data.empty?

      switch_ports.each do |switch_port|
        switch_port = switch_port.strip.gsub(/\s+/, ' ').split

        h = network_interface_template

        port_id = offset == 1 ? switch_port[1] + '/' + switch_port[2] : switch_port[1]

        portshow_data = @connector.values_at("portshow #{port_id}")
        
        h[:model] = 'Unknown Fibre Adapter'
        h[:name] = 'fc' + port_id
        h[:port_wwn] = portshow_data.grep(/portwwn\:/i)[0].split.last.upcase

        h[:type] = 'fibre'
        h[:status] = switch_port[5 + offset] =~ /online/i ? 'up' : 'down'
        h[:vendor] = VENDOR_BROCADE

        if h[:status] == 'up'
          speed = switch_port[4 + offset]
          h[:auto_negotiate] = true if speed =~ /^N/
          h[:current_speed_mbps] = speed.scan(/\d+/).join.to_i * 1000

          remote_wwns = portshow_data.join("\n").extract(/portWwn of device\(s\) connected\:(.*)Distance/im).strip.split(/\n/)

          if switch_port.join =~ /upstream/i || remote_wwns.count > 1
            h[:is_uplink] = true
          elsif remote_wwns.count == 1
            h[:remote_wwn] = remote_wwns[0].strip
          end
        end

        @network_interfaces << h
      end

      @network_interfaces
    end
    
    def get_operating_system
      super
      
      @operating_system[:kernel] = version_data.grep(/kernel/i)[0].after_colon
      @operating_system[:name] = 'Brocade Fabric OS'
      @operating_system[:version] = version_data.grep(/fabric os/i)[0].after_colon.delete('v')

      @operating_system
    end

    def get_running_processes; super; end

  end
end; end