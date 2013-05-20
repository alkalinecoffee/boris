require 'boris/profiler'

module Boris; module Profilers
  class Cisco < Base

    attr_reader :version_data
    
    def self.connection_type
      Boris::SSHConnector
    end

    def get_version_data
      @version_data ||= @connector.values_at('show version | include (Version|ROM|uptime|CPU|bytes of memory)')
    end

    def get_file_systems; super; end

    def get_hardware
      super
      
      get_version_data

      cpu_data = @version_data.grep(/cpu/i)[0]

      version_data = @version_data.join("\n")

      @hardware[:cpu_model] = cpu_data.extract(/\s*(\w+) CPU/)
      @hardware[:cpu_physical_count] = 1

      cpu_speed = cpu_data.extract(/CPU at (\d+(?=[ghz|mhz]))/i).to_i

      @hardware[:cpu_speed_mhz] = cpu_data =~ /ghz/i ? cpu_speed * 1000 : cpu_speed
      @hardware[:firmware_version] = version_data.extract(/ROM: (.+)/i)

      hardware_data = @connector.values_at('show idprom chassis | include (OEM|Product|Serial Number)')

      @hardware[:model] = hardware_data.grep(/product/i)[0].value_after_character('=')
      @hardware[:memory_installed_mb] = 512
      @hardware[:serial] = hardware_data.grep(/serial number/i)[0].value_after_character('=')
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

      get_version_data

      @network_id[:hostname] = @version_data.grep(/uptime is/)[0].strip.extract(/^(.+) uptime is/i)
      @network_id
    end
    
    def get_network_interfaces
      super

      interface_data = @connector.values_at('show interface | include (protocol|Hardware|Internet|MTU|duplex|Members)').join("\n").split(/^(?=\w)/)

      physical_uplink_ports = []

      interface_data.each do |interface|

        # don't bother with LOM ports
        next if interface =~ /out of band/i

        h = network_interface_template

        interface = interface.split(/\n/)

        status = interface.grep(/protocol/)[0]
        hardware = interface.grep(/hardware/i)[0]
        ip = interface.grep(/internet address/i)[0]
        mtu = interface.grep(/mtu/i)[0]
        

        h[:mac_address] = hardware.extract(/\(bia (.+)\)/i).delete('.').scan(/../).join(':').upcase
        h[:mtu] = mtu.extract(/mtu (\d+) bytes/i).to_i
        h[:model] = hardware.extract(/hardware is (.+),/i)

        h[:name] = status.split[0]

        if h[:name] =~ /port\-*channel/i
          physical_uplink_ports.concat(interface.grep(/members in this channel/i)[0].after_colon.strip.split)
        end

        h[:status] = status =~ /down/i ? 'down' : 'up'
        h[:type] = 'ethernet'
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
        short_name = h[:name].sub(h[:name].extract(/^..(\D+)/), '')

        remote_mac_addresses = mac_address_table.grep(/#{h[:name]}/)

        if physical_uplink_ports.include?(short_name) || remote_mac_addresses.count > 1
          h[:is_uplink] = true
        elsif remote_mac_addresses.any?
          h[:remote_mac_address] = remote_mac_addresses[0].split[1].delete('.').scan(/../).join(':').upcase
        end
      end

      @network_interfaces
    end

    def get_operating_system
      super

      get_version_data
    end

  end
end; end