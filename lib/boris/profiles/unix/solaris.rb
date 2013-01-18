require 'boris/profiles/unix_core'

module Boris; module Profiles
  module Solaris
    
    include UNIX
    
    SOLARIS_ZONE_MODEL = 'Oracle Virtual Platform'
    
    def self.matches_target?(active_connection)
      return true if active_connection.value_at('uname') =~ /sunos/i
    end

    def get_hardware
      super

      detect_platform if !@platform
      detect_zone if !@zone

      if @zone == :child
        @hardware[:vendor] = VENDOR_ORACLE
        @hardware[:model] = SOLARIS_ZONE_MODEL
      elsif @platform == :sparc
        @hardware[:vendor] = VENDOR_ORACLE

        @hardware[:firmware_version] = @active_connection.value_at(%q{/usr/platform/`uname -m`/sbin/prtdiag -v | egrep -i "^obp" | awk '{print $2}'})
        model_data = @active_connection.value_at('/usr/sbin/prtconf -b | grep banner-name')
        @hardware[:model] = model_data.after_colon
      else
        @hardware[:firmware_version] = @active_connection.value_at('/usr/sbin/smbios -t SMB_TYPE_BIOS | grep -i "version string"').after_colon
        model_data = @active_connection.values_at("/usr/sbin/smbios -t SMB_TYPE_SYSTEM | egrep -i 'manufacturer|product|serial'")
        @hardware[:vendor] = model_data.grep(/manufacturer/i)[0].after_colon
        @hardware[:model] = model_data.grep(/product/i)[0].after_colon
        @hardware[:serial] = model_data.grep(/serial number/i)[0].after_colon
      end

      memory_data = @active_connection.value_at("/usr/sbin/prtconf | egrep -i 'memory size' | awk '{print $3}'")
      @hardware[:memory_installed_mb] = memory_data.to_i

      cpu_arch_data = @active_connection.values_at("isainfo -v | egrep -i applications | awk '{print $1}'")
      @hardware[:cpu_architecture] = cpu_arch_data.include?('64-bit') ? 64 : 32

      cpu_data = @active_connection.values_at(%q{kstat -m cpu_info | nawk '{if($1~/^(chip_id|core_id|clock_mhz|vendor_id|brand)/) {sub($1, $1"|"); print $0}}'})

      @hardware[:cpu_physical_count] = cpu_data.grep(/chip_id/i).uniq.size
      @hardware[:cpu_core_count] = cpu_data.grep(/core_id/i).uniq.size / @hardware[:cpu_physical_count]
      @hardware[:cpu_model] = cpu_data.grep(/brand/i)[0].after_pipe
      @hardware[:cpu_speed_mhz] = cpu_data.grep(/clock_mhz/i)[0].after_pipe.to_i

      @hardware[:cpu_vendor] = if @platform == :sparc
        VENDOR_ORACLE
      else
        cpu_data.grep(/vendor_id/i)[0].after_pipe
      end
    end

    def get_hosted_shares
      super

      share_data = @active_connection.values_at(%q{nawk '{system("df -k | grep " $2)}' /usr/sbin/shares | nawk '{print $NF "|" $1}'})
      share_data.each do |share|
        h = hosted_share_template
        share = share.split('|')
        h[:name] = share[0]
        h[:path] = share[1]
        @hosted_shares << h
      end
    end

    def get_installed_applications
      super

      application_data = @active_connection.values_at("pkginfo -il -c application | egrep -i '^$|(name|version|basedir|vendor|instdate):'")
      application_data.split("\n\n").each do |application|

        application = application.split("\n")
        h = installed_application_template

        h[:date_installed] = DateTime.parse(application.grep(/instdate:/i)[0].split(/instdate:/i)[1])
        h[:install_location] = application.grep(/basedir:/i)[0].after_colon
        h[:name] = application.grep(/name:/i)[0].after_colon
        h[:vendor] = application.grep(/vendor:/i)[0].after_colon
        h[:version] = application.grep(/version:/i)[0].after_colon

        @installed_applications << h
      end
    end

    def get_installed_patches
      super

      # get list of patch install directories and their modified date.  this will be our de-facto
      # list of installed patches on a host.

      patch_directories = @active_connection.values_at(%q{ls -ego /var/sadm/patch | grep -v '^total' | nawk '{print $NF "|" $4 " " $5 " " $6 " " $7}'})

      patch_directories.each do |directory|
        
        h = installed_patch_template

        directory = directory.split('|')

        h[:patch_code] = directory[0]
        h[:date_installed] = DateTime.parse(directory[1])

        @installed_patches << h
      end
    end

    def get_installed_services
      super

      service_data = @active_connection.values_at("svcs -a | nawk '{print $NF}'")
      service_data.each do |service|
        h = installed_service_template
        h[:name] = service

        @installed_services << h
      end
    end

    def get_local_user_groups; super; end

    def get_network_interfaces
      super

      detect_platform if !@platform
      detect_zone if !@zone

      ## ETHERNET
      # get some basic info that will apply to all ethernet interfaces
      dns_servers = @active_connection.values_at("cat /etc/resolv.conf | grep ^nameserver | awk '{print $2}'")

      # first, grab the link properties for all connections via the kstat command
      link_properties = @active_connection.values_at(%q{/usr/bin/kstat -c net -p | egrep "ifspeed|link_(up|duplex|autoneg)" | nawk '{print $1 "|" $2}'})

      # then get ethernet interface config from ifconfig
      interface_configs = @active_connection.values_at(%q{/sbin/ifconfig -a | egrep 'flags|inet|zone' | nawk '{if($2~/^flags/ && $1!~/^(lo|dman|sppp)/) {current_line=$0; getline; {if($1!~/^zone/) {$1=$1; print current_line "\n" $0 "\n"}}}}'}).join("\n").strip.split(/\n\n/)

      # now get the macs of active ethernet connections (for backup in cases where we
      # can't get macs from prtpicl)
      mac_mapping = @active_connection.values_at(%q{/usr/bin/netstat -pn | grep SP | nawk '{print $1 "|" $2 "|" toupper($5)}'})

      # now create a definitive list of interfaces found on this host.  to do this, we pull
      # the interfaces from the link_properties (kstat cmd) output.
      found_ethernet_interfaces = []
      link_properties.grep(/:ifspeed\|/).each do |i|
        i = i.strip.split(':')
        found_ethernet_interfaces << {:driver=>i[0], :instance=>i[1]}
      end

      # if this host is in a child zone, drop any interfaces that are not found in the ifconfig
      # command output (since these would likely be picked up when scanning the zone host)
      if @zone == :child
        found_ethernet_interfaces.delete_if{|fi| interface_configs.select{|config| config =~ /^#{fi[:driver]}#{fi[:instance]}/}.count == 0}
      end

      # now loop through each unique ethernet interface found on this host
      found_ethernet_interfaces.uniq.each do |fi|
        h = network_interface_template

        h[:dns_servers] = dns_servers
        h[:name] = fi[:driver] + fi[:instance]
        
        # set some defaults for this interface
        h[:mac_address] = '00:00:00:00:00:00'
        h[:model] = 'Unknown Ethernet Adapter'
        h[:status] = 'down'
        h[:type] = 'ethernet'
        h[:vendor] = 'Unknown'

        # grab the ifconfig output matching this interface
        matched_ifconfig_data = interface_configs.grep(/#{h[:name]}:/)
        matched_ifconfig_data.each do |ifconfig_data|
          ifconfig_data = ifconfig_data.split(/\n/)
          interface_line = ifconfig_data[0].split
          inet_line = ifconfig_data[1].split

          subnet = inet_line[3] ? inet_line[3].hex_to_address : nil

          h[:status] = 'up' if interface_line[1] =~ /<up/i

          if h[:status] == 'up'
            h[:mtu] = interface_line[3].to_i unless h[:mtu]
            h[:ip_addresses] << {:ip_address=>inet_line[1], :subnet=>subnet}
          end
        end

        # for a child zone, set default ethernet interface model/vendor. for zone host,
        # run prtpicl command to grab hardware details
        if @zone == :child
          h[:model] = 'Virtual Ethernet Adapter'
          h[:vendor] = VENDOR_ORACLE
        else
          prtpicl_command = %q{/usr/sbin/prtpicl -c network -v | egrep ':model|:driver-name|:instance|:local-mac-address|:vendor-id|:device-id|\(network' | nawk '{if ($0 ~ /\(network/) print ""; else {$1=$1; split($0, str, /\t/); print str[1] "|" str[2];}}'}

          prtpicl_command.gsub!(/network/, 'obp-device') if @platform == :x86

          hardware_details = @active_connection.values_at(prtpicl_command).join("\n").split(/\n\n/)

          hardware = hardware_details.grep(/driver-name\|.*#{fi[:driver]}/).grep(/instance\|.*#{fi[:instance]}/)[0].split(/\n/)

          h[:vendor_id] = hardware.grep(/vendor-id\|/)[0].after_pipe unless hardware.grep(/vendor-id\|/).empty?
          h[:model_id] = hardware.grep(/device-id\|/)[0].after_pipe unless hardware.grep(/device-id\|/).empty?
          
          h[:vendor] = hardware.grep(/vendor\|/)[0].after_pipe unless hardware.grep(/vendor\|/).empty?
          h[:model] = hardware.grep(/model\|/)[0].after_pipe unless hardware.grep(/model\|/).empty?

          # try grabbing the mac from the hardware details (hit or miss if it's there)
          h[:mac_address] = hardware.grep(/local-mac-address\|/)[0].after_pipe.gsub(/\s+/, ':').upcase unless hardware.grep(/local-mac-address\|/).empty?
        end

        # make another attempt at grabbing the mac, this time checking output from netstat,
        # which would only apply to active connections
        netstat_mac = mac_mapping.select{|mac| mac.strip =~ /^#{fi[:driver]}#{fi[:instance]}\|/}
        h[:mac_address] = netstat_mac[0].after_pipe unless netstat_mac.empty?
      
        # grab link properties from the kstat command results
        properties = link_properties.select{|l| l.strip =~ /^#{fi[:driver]}:#{fi[:instance]}/}

        # override status if the link is down
        h[:status] = 'down' if properties.grep(/:link_up\|/)[0].after_pipe != '1'

        if h[:status] == 'up'
          speed = properties.grep(/:ifspeed\|/)
          h[:current_speed_mbps] = speed[0].after_pipe.to_i / 1000 / 1000 unless speed.empty?

          auto_negotiate_setting = properties.grep(/:link_autoneg\|/)
          h[:auto_negotiate] = case auto_negotiate_setting[0].after_pipe.to_i
            when 1; true
            else; false
          end unless auto_negotiate_setting.empty?
          
          duplex_setting = properties.grep(/:link_duplex\|/)
          h[:duplex] = case duplex_setting[0].after_pipe
            when '2' || 'full'; 'full'
            when '1' || 'half'; 'half'
          end unless duplex_setting.empty?

        end
        
        @network_interfaces << h

      end

      ## FIBRE CHANNEL
      hba_ports = @active_connection.values_at(%q{/usr/local/bin/sudo /usr/sbin/fcinfo hba-port | egrep -i "wwn|device name|model|manufacturer|driver name|state|current speed" | nawk '{$1=$1; if(tolower($1) ~ /^node/) print $0 "\n"; else print $0;}'})
      hba_ports = hba_ports.join("\n").split(/\n\n/)
      hba_ports.each do |hba|
        hba = hba.split(/\n/)

        h = network_interface_template

        h[:name] = hba.grep(/os device name/i)[0].after_colon
        h[:node_wwn] = hba.grep(/node wwn/i)[0].after_colon
        h[:port_wwn] = hba.grep(/port wwn/i)[0].after_colon
        
        h[:model] = hba.grep(/model/i)[0].after_colon
        h[:vendor] = hba.grep(/manufacturer/i)[0].after_colon
        
        h[:status] = hba.grep(/state/i)[0].after_colon =~ /online/i ? 'up' : 'down'
        h[:type] = 'fibre'

        current_speed = hba.grep(/current speed/i)[0].after_colon
        speed = current_speed.scan(/\d/).join.to_i
        h[:current_speed_mbps] = current_speed =~ /gb/i ? speed * 1000 : speed
        
        @network_interfaces << h
      end
    end

    def get_operating_system
      super

      install_log_date = @active_connection.value_at("ls -l /var/sadm/system/logs/install_log | nawk '{print $6" "$7" "$8'}")
      @operating_system[:date_installed] = DateTime.parse(install_log_date)

      os_data = @active_connection.value_at('uname -rv').split
      @operating_system[:kernel] = os_data[1]
      @operating_system[:name] = 'Oracle Solaris'
      @operating_system[:version] = os_data[0]
    end

    private
    
    def detect_platform
      platform = @active_connection.values_at('showrev').grep(/application architecture/i)[0].after_colon
      @platform = platform =~ /sparc/i ? :sparc : :x86
    end

    def detect_zone
      zone = @active_connection.values_at('/usr/sbin/zoneadm list')
      @zone = zone.include?('global') ? :global : :child
    end
  end
end; end
