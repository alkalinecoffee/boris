require 'boris/profiler'

module Boris; module Profilers
  class Cisco < Profiler
    def self.connection_type
      Boris::SSHConnector
    end

    def check_for_version_data
      @version_data ||= @connector.values_at('show version | include (Version|uptime|CPU|bytes of memory)')
    end

    def get_file_systems; super; end

    def get_hardware
      super
      
      check_for_version_data

      cpu_data = @version_data.grep(/cpu/i)[0]

      version_data = @version_data.join("\n")

      @hardware[:cpu_model] = cpu_data.scan(/\s*(\w+) CPU/).join
      @hardware[:cpu_physical_count] = 1

      cpu_speed = cpu_data.scan(/CPU at (\d+(?=[ghz|mhz]))/i).join.to_i

      @hardware[:cpu_speed_mhz] = cpu_data =~ /ghz/i ? cpu_speed * 1000 : cpu_speed
      @hardware[:firmware_version] = version_data.scan(/Version (.+),/i).join

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

      check_for_version_data

      @network_id[:hostname] = @version_data.grep(/uptime is/)[0].scan(/(\w+) uptime is/i).join
      @network_id
    end
    
    # def get_network_interfaces
    #   super

    #   dns_servers = @connector.values_at('list sys dns').grep(/servers/)[0].between_curlies.strip.split

    #   interfaces = []
    #   @connector.values_at('list net interface all-properties').join("\n").split(/\}/).each do |interface|
    #     interface = interface.strip.split(/\n/)
    #     h = network_interface_template

    #     h[:mac_address] = interface.grep(/mac\-address/)[0].split.last.pad_mac_address
    #     h[:model] = 'Unknown Ethernet Adapter'
    #     h[:name] = interface[0].split[2]

    #     interfaces << h
    #   end

    #   interface_properties = @connector.values_at('show net interface all-properties field-fmt').grep(/\{|\}|media|status|trunk/)
    #   interface_properties = interface_properties.join("\n").split(/^\s*net/)

    #   vlans = @connector.values_at('list net vlan').grep(/\{|\}/)
    #   vlans = vlans.join("\n").split(/^\s*net/)

    #   self_ips = @connector.values_at('show running-config net self all-properties').grep(/\{|vlan|address|\}/)
    #   self_ips = self_ips.join("\n").split(/^\s*net/)

    #   interfaces.each do |h|

    #     next if h[:mac_address] =~ /none/i

    #     properties = interface_properties.grep(/interface #{h[:name]} \{/).join.split(/\n/)

    #     h[:status] = properties.grep(/status/i)[0].split.last
    #     h[:status] = 'down' unless h[:status] == 'up'
        
    #     media = properties.grep(/media\-active/i)[0].split.last
    #     media = nil if media =~ /none/i

    #     h[:type] = 'ethernet'
    #     h[:vendor] = VENDOR_F5

    #     if h[:status] == 'up'
    #       h[:current_speed_mbps] = media.scan(/\d+/)[0].to_i
    #       h[:dns_servers] = dns_servers
    #       h[:duplex] = case
    #       when media =~ /fd$/i
    #         'full'
    #       when media =~ /hd$/i
    #         'half'
    #       end

    #       #h[:mtu] = properties.grep(/mtu/i)[0].split.last.to_i

    #       trunk = properties.grep(/trunk\-name/i)[0].split.last
    #       trunk = nil if trunk =~ /none/i

    #       bound_vlans = []

    #       [h[:name], trunk].each do |interface_name|
    #         matched_vlans = vlans.grep(/ #{interface_name} \{/)

    #         matched_vlans.each do |matched_vlan|
    #           bound_vlans << matched_vlan.split[1]
    #         end
    #       end

    #       bound_vlans.each do |bound_vlan|
    #         bound_ips = self_ips.grep(/vlan #{bound_vlan}/)

    #         bound_ips.each do |bound_ip|
    #           bound_ip = bound_ip.split(/\n/)

    #           # bigip version 10 reports ip address as first line, where
    #           # version 11 reports ip on its own line with bitmask attached
    #           ip_data = if bound_ip[1] =~ /address/i #aka version 11
    #             bound_ip.grep(/address/)[0].split.last
    #           else #aka version 10
    #             bound_ip.grep(/self/)[0].split[1]
    #           end

    #           ip_data = ip_data.split(/\//)

    #           ip_address = ip_data.first
    #           subnet = NetAddr.i_to_ip(NetAddr.bits_to_mask(ip_data.last.to_i, NetAddr::CIDRv4))
                
    #           h[:ip_addresses] << {:ip_address=>ip_address, :subnet=>subnet}
    #         end
    #       end
    #     end

    #     @network_interfaces << h
    #   end

    #   @network_interfaces
    # end

    def get_operating_system
      super

      check_for_version_data
    end

  end
end; end