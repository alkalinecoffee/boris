require 'boris/profiler_core'

module Boris; module Profilers
  class OnboardAdministratorCore
    include ProfilerCore
    
    attr_reader :enclosure_data

    def self.connection_type
      Boris::SSHConnector
    end

    def enclosure_data
      @enclosure_data ||= @connector.values_at('show enclosure info')
    end

    def fru_data
      @fru_data ||= @connector.values_at('show fru')
    end

    def get_file_systems; super; end

    def get_hardware
      super

      enclosure_data

      @hardware[:firmware_version] = fru_data.grep(/firmware version/i)[0].after_colon
      @hardware[:model] = enclosure_data.grep(/enclosure type/i)[0].after_colon
      @hardware[:serial] = enclosure_data.grep(/serial number/i)[0].after_colon
      @hardware[:vendor] = VENDOR_HP

      @hardware
    end

    def get_hosted_shares; super; end
    def get_installed_applications; super; end
    def get_installed_patches; super; end
    def get_installed_services; super; end
    def get_local_user_groups; super; end
    
    def get_network_id
      super

      @network_id[:hostname] = enclosure_data.grep(/enclosure name/i)[0].after_colon

      @network_id
    end
    
    def get_network_interfaces
      super

      ethernet_interfaces = @connector.values_at('show oa network all').join("\n").strip.split(/Onboard Administrator #\d/i)[1..-1]

      ethernet_interfaces.each do |interface|
        interface = interface.split(/\n/)

        h = network_interface_template

        h[:mac_address] = interface.grep(/mac address/i)[0].split.last
        h[:model] = 'Unknown Ethernet Adapter'
        h[:name] = interface.grep(/name/i)[0].after_colon
        h[:status] = interface.grep(/link status/i)[0] =~ /not active/i ? 'down' : 'up'
        h[:type] = 'ethernet'
        h[:vendor] = VENDOR_HP

        if h[:status] == 'up'
          link_settings = interface.grep(/link settings/i)[0]

          h[:auto_negotiate] = link_settings =~ /auto/i ? true : nil
          h[:current_speed_mbps] = link_settings.extract(/(\d+) mbps/i).to_i
          h[:duplex] = link_settings =~ /half duplex/i ? 'half' : 'full'
          ip_address = interface.grep(/ipv4 address/i)[0].after_colon
          subnet_mask = interface.grep(/netmask/i)[0].after_colon
          h[:ip_addresses] << {:ip_address=>ip_address, :subnet=>subnet_mask}
        end
        
        @network_interfaces << h
      end

      @network_interfaces
    end
    
    def get_operating_system
      super

      @operating_system[:name] = 'HP Onboard Administrator'
      @operating_system[:version] = fru_data.grep(/firmware version/i)[0].after_colon

      @operating_system
    end

    def get_running_processes; super; end

  end
end; end