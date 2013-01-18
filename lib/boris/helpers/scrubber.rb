module Boris; module Profiles
  module Structure
    def scrub_data!
      [ @file_systems,
        @hosted_shares,
        @installed_applications,
        @installed_patches,
        @installed_services,
        @local_user_groups,
        @network_interfaces
      ].each {|arr| arr.strip_string_values_in_array}

      [@hardware, @network_id, @operating_system].each {|h| h.strip_string_values_in_hash}

      @installed_applications.each do |app|
        app[:name].string_clean
        app[:vendor].format_vendor unless app[:vendor]
      end

      @network_id[:hostname].upcase!
      @network_id[:domain].downcase! unless !@network_id[:domain]

      @network_interfaces.each do |interface|
        interface[:fabric_name].downcase! unless !interface[:fabric_name]
        interface[:mac_address].upcase! unless !interface[:mac_address]
        interface[:model] = interface[:model].format_model unless interface[:model].format_vendor
        interface[:node_wwn].downcase! unless !interface[:node_wwn]
        interface[:port_wwn].downcase! unless !interface[:port_wwn]
        interface[:remote_mac_address].upcase! unless !interface[:remote_mac_address]
        interface[:vendor] = interface[:vendor].format_vendor unless !interface[:vendor]
      end

      @hardware[:cpu_vendor] = @hardware[:cpu_vendor].string_clean.format_vendor unless !@hardware[:cpu_vendor]
      @hardware[:model] = @hardware[:model].format_model unless !@hardware[:model]
      @hardware[:serial].upcase unless !@hardware[:serial]
      @hardware[:vendor] = @hardware[:vendor].string_clean.format_vendor unless !@hardware[:vendor]

      @operating_system[:license_key].upcase unless !@operating_system[:license_key]
    end
  end
end; end