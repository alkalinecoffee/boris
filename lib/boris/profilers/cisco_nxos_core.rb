require 'boris/profiler_core'

module Boris; module Profilers
  class CiscoNXOSCore
    include ProfilerCore

    attr_reader :version_data
    
    def self.connection_type
      Boris::SSHConnector
    end

    def version_data
      @version_data ||= @connector.values_at('show version | grep -i "bios:\|system version\|chassis\|memory\|device"')
    end

    def get_file_systems; super; end

    def get_hardware
      super
      
      cpu_data = version_data.grep(/cpu/i)[0]

      @hardware[:cpu_model] = cpu_data.extract(/\s*(.*)\s*with/).strip
      @hardware[:cpu_physical_count] = 1

      @hardware[:firmware_version] = version_data.join("\n").extract(/BIOS\:\s*version\s*(.+)/i)

      hardware_data = @connector.values_at('show sprom backplane | grep Product\|Serial')

      @hardware[:model] = hardware_data.grep(/product number/i)[0].after_colon
      @hardware[:memory_installed_mb] = cpu_data.extract(/(\d+) kb/i).to_i / 1024
      @hardware[:serial] = hardware_data.grep(/serial number/i)[0].after_colon
      @hardware[:vendor] = VENDOR_CISCO

      @hardware
    end

    def get_hosted_shares; super; end
    def get_installed_applications; super; end
    def get_installed_patches; super; end
    def get_installed_services; super; end
    def get_local_user_groups; super; end
    
    def get_network_id
      super

      @network_id[:hostname] = version_data.grep(/device name/i)[0].after_colon
      
      @network_id
    end
    
    def get_network_interfaces
      super

      interface_data = @connector.values_at('show interface | grep "is up\|is down\|Hardware\|Internet\|MTU\|duplex\|Members"').join("\n").split(/^(?=\w)/)

      physical_uplink_ports = []

      interface_data.each do |interface|

        # don't bother with LOM ports
        next if interface =~ /mgmt\d/i

        h = network_interface_template

        interface = interface.split(/\n/)

        status = interface.grep(/is up|is down/)[0]
        hardware = interface.grep(/hardware/i)[0].gsub(': ', ' is ')
        ip = interface.grep(/internet address/i)[0]
        mtu = interface.grep(/mtu/i)[0]
      
        h[:mac_address] = hardware.extract(/address is\s*(.{4}\..{4}\..{4})/i).delete('.').scan(/../).join(':').upcase
        h[:mtu] = mtu.extract(/mtu (\d+) bytes/i).to_i
        h[:model] = hardware.extract(/hardware is (.+),/i)

        h[:name] = status.split[0]

        if h[:name] =~ /port\-*channel/i
          physical_uplink_ports.concat(interface.grep(/members in this channel/i)[0].after_colon.strip.split)
          h[:type] = 'port-channel'
        else
          h[:type] = 'ethernet'
        end

        h[:status] = status =~ /down/i ? 'down' : 'up'
        h[:vendor] = VENDOR_CISCO

        connection = interface.grep(/duplex/i)[0]

        if connection && h[:status] == 'up'
          connection = connection.split(',')
          h[:auto_negotiate] = true if connection[2] =~ /link type is auto/i
          
          if connection[1] =~ /mb|gb/i
            speed = connection[1].extract(/(\d+)/i).to_i
            h[:current_speed_mbps] = connection[1] =~ /gb/i ? speed * 1000 : speed
          end

          h[:duplex] = connection[0].extract(/(\w+)-duplex/i).downcase
        end
        
        if ip
          ip_data = ip.extract(/internet address is (.+)$/i).split(/\//)

          ip_address = ip_data.first
          subnet = NetAddr.i_to_ip(NetAddr.bits_to_mask(ip_data.last.to_i, NetAddr::CIDRv4))
            
          h[:ip_addresses] << {:ip_address=>ip_address, :subnet=>subnet}
        end

        @network_interfaces << h
      end

      mac_address_table = @connector.values_at('show mac-address-table')

      @network_interfaces.each do |h|
        short_name = if h[:name] =~ /ethernet/i
          h[:name].sub(h[:name].extract(/^...(\D+)/), '')
        else
          h[:name].sub(h[:name].extract(/^..(\D+)/), '')
        end

        remote_mac_addresses = mac_address_table.grep(/#{short_name}/i)

        if physical_uplink_ports.include?(short_name) || remote_mac_addresses.count > 1
          h[:is_uplink] = true
        elsif remote_mac_addresses.any?
          h[:remote_mac_address] = remote_mac_addresses[0].split[2].delete('.').scan(/../).join(':').upcase
        end
      end

      @network_interfaces
    end

    def get_operating_system
      super

      @operating_system[:kernel] = version_data.grep(/system version/i)[0].after_colon
      @operating_system[:name] = 'Cisco Nexus Operating System'
      @operating_system[:version] = @operating_system[:kernel].split('(')[0]

      @operating_system
    end

  end
end; end
