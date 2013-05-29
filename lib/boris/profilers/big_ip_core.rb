require 'boris/profiler_core'

module Boris; module Profilers
  class BigIPCore
    include ProfilerCore
    
    attr_reader :license_data, :os_data

    def self.connection_type
      Boris::SSHConnector
    end

    def license_data
      @license_data ||= @connector.values_at('show sys license')
    end

    def os_data
      @os_data ||= @connector.values_at('show sys version')
    end

    def get_file_systems; super; end

    def get_hardware
      super
      
      hardware_data = @connector.values_at('show sys hardware').join("\n").split(/\n\s*\n/)
      cpu_mem_data = @connector.values_at('show sys host').join("\n").split(/\n\s*\n/)

      cpu_data = hardware_data.grep(/name\s+cpus/i)[0].split(/\n/)
      platform_data = hardware_data.grep(/platform/i)[0].split(/\n/)
      mem_data = cpu_mem_data.grep(/memory \(bytes\)/i)[0].split(/\n/)

      @hardware[:cpu_core_count] = cpu_data.grep(/\s{2,}cores/i)[0].split(/\s+/)[2].to_i
      @hardware[:cpu_model] = cpu_data.grep(/model/i)[0].split(/\s{2,}/).last
      @hardware[:cpu_physical_count] = cpu_mem_data.grep(/\s{2,}cpu count/i)[0].split.last.to_i
      @hardware[:cpu_speed_mhz] = cpu_data.grep(/cpu mhz/i)[0].split.last.to_i
      firmware = platform_data.grep(/bios revision/i)[0].split(/\s{2,}/).last
      @hardware[:firmware_version] = firmware =~ /bios|ver\:/i ? firmware.split(/bios|ver\:/i).last : firmware
      @hardware[:model] = platform_data.grep(/name/i)[0].split(/\s{2,}/).last + " (#{license_data.grep(/platform id/i)[0].split.last})"
      
      memory = mem_data.grep(/total/i)[0].split.last
      @hardware[:memory_installed_mb] = if memory =~ /g$/i
        (memory.sub('g', '').to_f * 1024).to_i
      elsif memory =~ /m$/i
        memory.sub('m', '').to_f
      end
      
      @hardware[:serial] = hardware_data.grep(/system information/i)[0].split(/\n/).grep(/chassis serial/i)[0].split.last

      @hardware[:vendor] = VENDOR_F5

      @hardware
    end

    def get_hosted_shares; super; end
    
    def get_installed_applications
      super

      license_data.grep(/.*\(.*\)/).each do |application|
        h = installed_application_template

        h[:license_key] = application.between_parenthesis
        h[:name] = application.split('(')[0].strip
        h[:vendor] = VENDOR_F5

        @installed_applications << h
      end

      @installed_applications
    end
    
    def get_installed_patches
      super

      patch_data = os_data.join("\n")

      if patch_data =~ /hotfix list/i
        patch_data.split(/hotfix list/i).last.scan(/\w+/).each do |patch|
          @installed_patches << {:date_installed=>nil, :installed_by=>nil, :patch_code=>patch}
        end
      end

      @installed_patches
    end
    
    def get_installed_services; super; end
    def get_local_user_groups; super; end
    
    def get_network_id
      super

      hostname = @connector.values_at('list sys global-settings hostname').grep(/hostname/)[0].split.last.split('.')

      @network_id[:hostname] = hostname.shift
      @network_id[:domain] = hostname.join('.') if hostname.any?

      @network_id
    end
    
    def get_network_interfaces
      super

      dns_servers = @connector.values_at('list sys dns').grep(/servers/)[0].between_curlies.strip.split

      interfaces = []
      @connector.values_at('list net interface all-properties').join("\n").split(/\}/).each do |interface|
        interface = interface.strip.split(/\n/)
        h = network_interface_template

        h[:mac_address] = interface.grep(/mac\-address/)[0].split.last.pad_mac_address
        h[:model] = 'Unknown Ethernet Adapter'
        h[:name] = interface[0].split[2]

        interfaces << h
      end

      interface_properties = @connector.values_at('show net interface all-properties field-fmt').grep(/\{|\}|media|status|trunk/)
      interface_properties = interface_properties.join("\n").split(/^\s*net/)

      vlans = @connector.values_at('list net vlan').grep(/\{|\}/)
      vlans = vlans.join("\n").split(/^\s*net/)

      self_ips = @connector.values_at('show running-config net self all-properties').grep(/\{|vlan|address|\}/)
      self_ips = self_ips.join("\n").split(/^\s*net/)

      interfaces.each do |h|

        next if h[:mac_address] =~ /none/i

        properties = interface_properties.grep(/interface #{h[:name]} \{/).join.split(/\n/)

        h[:status] = properties.grep(/status/i)[0].split.last
        h[:status] = 'down' unless h[:status] == 'up'
        
        media = properties.grep(/media\-active/i)[0].split.last
        media = nil if media =~ /none/i

        h[:type] = 'ethernet'
        h[:vendor] = VENDOR_F5

        if h[:status] == 'up'
          h[:current_speed_mbps] = media.scan(/\d+/)[0].to_i
          h[:dns_servers] = dns_servers
          h[:duplex] = case
          when media =~ /fd$/i
            'full'
          when media =~ /hd$/i
            'half'
          end

          #h[:mtu] = properties.grep(/mtu/i)[0].split.last.to_i

          trunk = properties.grep(/trunk\-name/i)[0].split.last
          trunk = nil if trunk =~ /none/i

          bound_vlans = []

          [h[:name], trunk].each do |interface_name|
            matched_vlans = vlans.grep(/ #{interface_name} \{/)

            matched_vlans.each do |matched_vlan|
              bound_vlans << matched_vlan.split[1]
            end
          end

          bound_vlans.each do |bound_vlan|
            bound_ips = self_ips.grep(/vlan #{bound_vlan}/)

            bound_ips.each do |bound_ip|
              bound_ip = bound_ip.split(/\n/)

              # bigip version 10 reports ip address as first line, where
              # version 11 reports ip on its own line with bitmask attached
              ip_data = if bound_ip[1] =~ /address/i #aka version 11
                bound_ip.grep(/address/)[0].split.last
              else #aka version 10
                bound_ip.grep(/self/)[0].split[1]
              end

              ip_data = ip_data.split(/\//)

              ip_address = ip_data.first
              subnet = NetAddr.i_to_ip(NetAddr.bits_to_mask(ip_data.last.to_i, NetAddr::CIDRv4))
                
              h[:ip_addresses] << {:ip_address=>ip_address, :subnet=>subnet}
            end
          end
        end

        @network_interfaces << h
      end

      @network_interfaces
    end

    def get_operating_system
      super

      @operating_system[:kernel] = os_data.grep(/build/i)[0].split.last
      @operating_system[:license_key] = license_data.grep(/registration key/i)[0].split.last
      @operating_system[:name] = os_data.grep(/product/i)[0].split.last
      @operating_system[:service_pack] = os_data.grep(/edition/i)[0].split(/\s{2,}/).last
      @operating_system[:version] = os_data.grep(/version\s+/i)[0].split.last

      @operating_system
    end

  end
end; end