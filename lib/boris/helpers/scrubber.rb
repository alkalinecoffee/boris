require 'boris/helpers/string'

module Boris
  module Structure
    def scrub_data!
      [ @file_systems,
        @hosted_shares,
        @installed_applications,
        @installed_patches,
        @installed_services,
        @local_user_groups,
        @network_interfaces
      ].each {|arr| arr.strip_string_values_in_array if arr}
      debug 'string values from within data arrays cleaned up'

      [@hardware, @network_id, @operating_system].each {|h| h.strip_string_values_in_hash if h}
      debug 'string values from within data hashes cleaned up'

      @installed_applications.each do |app|
        app[:license_key].upcase! unless !app[:license_key]
        app[:name].string_clean
        app[:vendor].format_vendor unless !app[:vendor]
      end if @installed_applications
      debug 'installed application data cleaned up'

      if @network_id
        @network_id[:hostname].upcase! unless !@network_id[:hostname]
        @network_id[:domain].downcase! unless !@network_id[:domain]
      end
      debug 'network id data cleaned up'

      @network_interfaces.each do |interface|
        interface[:fabric_name].downcase! unless !interface[:fabric_name]
        interface[:mac_address].upcase! unless !interface[:mac_address]
        interface[:model] = interface[:model].format_model unless !interface[:model]
        interface[:node_wwn].downcase! unless !interface[:node_wwn]
        interface[:port_wwn].downcase! unless !interface[:port_wwn]
        interface[:remote_mac_address].upcase! unless !interface[:remote_mac_address]
        interface[:vendor] = interface[:vendor].format_vendor unless !interface[:vendor]
      end if @network_interfaces
      debug 'network interface data cleaned up'

      if @hardware
        @hardware[:cpu_model] = @hardware[:cpu_model].string_clean unless !@hardware[:cpu_model]
        @hardware[:cpu_vendor] = @hardware[:cpu_vendor].string_clean.format_vendor unless !@hardware[:cpu_vendor]
        @hardware[:model] = @hardware[:model].format_model unless !@hardware[:model]
        @hardware[:serial] = @hardware[:serial].format_serial unless !@hardware[:serial]
        @hardware[:vendor] = @hardware[:vendor].string_clean.format_vendor unless !@hardware[:vendor]
      end
      debug 'hardware data cleaned up'

      if @operating_system
        @operating_system[:license_key].upcase! unless !@operating_system[:license_key]
      end
      debug 'operating system data cleaned up'

      debug 'data scrubbing complete'
    end
  end
end