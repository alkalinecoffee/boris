require 'boris/profiler'

module Boris; module Profilers
  class Windows < Profiler

    APP32_KEYPATH = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    APP64_KEYPATH = 'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    
    NIC_CFG_KEYPATH = 'SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}'
    TCPIP_CFG_KEYPATH = 'SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'

    ORACLE_KEYPATH = 'SOFTWARE\ORACLE'
    IIS_KEYPATH = 'SOFTWARE\Microsoft\INetStp'

    DUPLEX_REG_VALS = [
      :autonegadvertised,
      :duplexmode,
      :forcedspeedduplex,
      :media_type,
      :mediaselect,
      :req_medium,
      :requestedmediatype,
      :speedduplex
    ]

    def self.connection_type
      Boris::WMIConnector
    end

    def self.matches_target?(connector)
      return true if connector.value_at('SELECT Name FROM Win32_OperatingSystem')[:name] =~ /windows/i
    end

    def get_file_systems
      super

      logical_disks = @connector.values_at('SELECT Antecedent, Dependent FROM Win32_LogicalDiskToPartition')
      disk_partitions = @connector.values_at('SELECT Antecedent, Dependent FROM Win32_DiskDriveToDiskPartition')
      physical_drives = @connector.values_at('SELECT DeviceID, Model FROM Win32_DiskDrive')
      disk_space = @connector.values_at('SELECT FreeSpace, Name, Size FROM Win32_LogicalDisk WHERE DriveType=3')
      
      disk_space.each do |ds|
        h = file_system_template
        h[:mount_point] = ds[:name]
        h[:capacity_mb] = ds[:size].to_i / 1024
        h[:used_space_mb] = h[:capacity_mb] - (ds[:freespace].to_i / 1024)

        ld = logical_disks.select{|ld| ld[:dependent].include?(h[:mount_point])}[0]
        h[:file_system] = ld[:antecedent].split(/\"/)[1]

        dp = disk_partitions.select{|dp| dp[:dependent].include?(h[:file_system])}[0]
        drive_id = dp[:antecedent].split('\\').last.delete('\"')

        physical_drive = physical_drives.select{|pd| pd[:deviceid].include?(drive_id)}[0]
        h[:san_storage] = true if physical_drive[:model] =~ /open-v/i

        @file_systems << h unless h[:file_system].nil?
      end

      @file_systems
    end

    def get_hardware
      super

      serial_data = @connector.value_at('SELECT SerialNumber, SMBIOSBIOSVersion FROM Win32_BIOS')
      @hardware[:serial] = serial_data[:serialnumber]
      @hardware[:firmware_version] = serial_data[:smbiosbiosversion]

      system_data = @connector.value_at('SELECT Manufacturer, Model, TotalPhysicalMemory FROM Win32_ComputerSystem')
      @hardware[:vendor] = system_data[:manufacturer]
      @hardware[:model] = system_data[:model]
      @hardware[:memory_installed_mb] = system_data[:totalphysicalmemory].to_i / 1024 / 1024

      cpu_data = @connector.values_at('SELECT * FROM Win32_Processor')

      @hardware[:cpu_physical_count] = cpu_data.size

      cpu = cpu_data.first

      @hardware[:cpu_architecture] = cpu[:datawidth]
      @hardware[:cpu_core_count] = cpu[:numberofcores]

      @hardware[:cpu_model] = cpu[:name]
      @hardware[:cpu_speed_mhz] = cpu[:maxclockspeed]
      @hardware[:cpu_vendor] = cpu[:manufacturer]

      @hardware
    end

    def get_hosted_shares
      super

      share_data = @connector.values_at('SELECT Name, Path FROM Win32_Share WHERE Type = 0')
      share_data.each do |share|
        h = hosted_share_template
        h[:name] = share[:name]
        h[:path] = share[:path]
        @hosted_shares << h
      end

      @hosted_shares
    end

    def get_installed_applications
      super

      @patches_from_registry = []

      [APP32_KEYPATH, APP64_KEYPATH].each do |app_path|
        @connector.registry_subkeys_at(app_path).each do |app_key|
          h = installed_application_template

          app_values = @connector.registry_values_at(app_key)

          if app_values[:installdate].kind_of?(String) && app_values[:installdate] !~ /0000/
            h[:date_installed] = DateTime.parse(app_values[:installdate])
          end

          if app_values.has_key?(:displayname) && !(app_values[:displayname] =~ /^kb|\(kb\d+/i)
            h[:install_location] = app_values[:installlocation] if app_values[:installlocation].nil?
            h[:license_key] = get_product_key(app_values[:displayname], app_key)
            h[:name] = concat_app_edition(app_values[:displayname])
            h[:vendor] = app_values[:publisher]
            h[:version] = app_values[:displayversion]

            @installed_applications << h
          elsif app_values[:displayname] =~ /^kb|\(kb\d+/i
            # likely a ms patch, so we'll save this data to parse later in #get_installed_patches
            @patches_from_registry << {:key_path=>app_key, :values=>app_values}
          end
        end
      end

      # look for some other popular applications not found in the usual spots

      # Oracle (RDMS, AppServer (AS), Client)
      oracle_keys = @connector.registry_subkeys_at(ORACLE_KEYPATH)
      oracle_keys.each do |app_key|
        if app_key =~ /^key_ora(db|home)/i
          app_values = registry_values_at(app_key)
          if app_values.has_key?(:oracle_group_name)
            h = installed_application_template
            h[:install_location] = app_values[:oracle_home]
            h[:name] = app_values[:oracle_group_name].split('_')[0] + " #{app_values[:oracle_bundle_name]}"
            h[:vendor] = VENDOR_ORACLE
            
            @installed_applications << h
          end
        end
      end

      @installed_applications
    end

    def get_installed_patches
      super

      # get patches via wmi
      patch_data = @connector.values_at('SELECT Description, HotFixID, InstalledBy, InstalledOn, ServicePackInEffect FROM Win32_QuickFixEngineering')

      patch_data.each do |patch|
        if !(patch[:hotfixid] =~ /\{/)
        
          h = installed_patch_template

          h[:patch_code] = patch[:hotfixid] == 'File 1' ? patch[:servicepackineffect] : patch[:hotfixid]

          h[:installed_by] = patch[:installedby] unless patch[:installedby].empty?
          h[:installed_by] = get_username(patch[:installedby]) if patch[:installedby][0, 4] == 'S-1-'

          h[:date_installed] = DateTime.strptime(patch[:installedon], '%m/%d/%Y') unless patch[:installedon].empty?

          @installed_patches << h
        end
      end

      # get patches from the registry (under the application keys) if necessary
      if @patches_from_registry.nil?
        @patches_from_registry = []

        [APP32_KEYPATH, APP64_KEYPATH].each do |app_path|
          @connector.registry_subkeys_at(app_path).each do |app_key|
            app_values = @connector.registry_values_at(app_key)
            if app_values[:displayname] =~ /^kb|\(kb\d+/i
              @patches_from_registry << {:key_path=>app_key, :values=>app_values}
            end
          end
        end
      end

      @patches_from_registry.each do |patch_hash|
        h = installed_patch_template

        key_path = patch_hash[:key_path].after_slash
        patch = patch_hash[:values]

        h[:date_installed] = DateTime.strptime(patch[:installdate], '%Y%m%d') if patch[:installdate].kind_of?(String)
        
        if key_path =~ /^kb/i
          h[:patch_code] = key_path
        elsif key_path.after_period =~ /^kb/i
          h[:patch_code] = key_path.after_period
        elsif patch[:displayname] =~ /\(kb\d+/i
          h[:patch_code] = patch[:displayname].between_parenthesis
        end

        @installed_patches << h if @installed_patches.select{|p| p[:patch_code] == h[:patch_code]}.empty?
      end

      @installed_patches
    end

    def get_installed_services
      super

      service_data = @connector.values_at('SELECT Name, PathName, StartMode FROM Win32_Service')
      service_data.each do |service|
        h = installed_service_template
        h[:name] = service[:name]
        h[:install_location] = service[:pathname]
        h[:start_mode] = service[:startmode]
        @installed_services << h
      end

      @installed_services
    end

    def get_local_user_groups
      super

      # first, retrieve the network id if necessary (will be used in later wmi queries)
      get_network_id if !@network_id || !@network_id[:hostname]

      # next, let's check if this system is a domain controller, otherwise, our query results
      # may return all user accounts associated with the domain
      if @operating_system.nil?
        system_roles = @connector.value_at('SELECT Roles FROM Win32_ComputerSystem')[:roles]
      else
        system_roles = @operating_system[:roles]
      end

      if system_roles.select{|role| role =~ /domaincontroller/i}.empty?
        # not a domain controller, so move on with retrieving users
        groups = []

        group_data = @connector.values_at("SELECT Name FROM Win32_Group WHERE Domain = '#{@network_id[:hostname]}'")
        group_data.each {|group| @local_user_groups << {:name=>group[:name], :members=>[]}}

        @local_user_groups.each do |group|
          
          members = @connector.values_at("SELECT * FROM Win32_GroupUser WHERE GroupComponent = \"Win32_Group.Domain='#{@network_id[:hostname]}',Name='#{group[:name]}'\"")

          members.each do |member|
            hostname, username = member[:partcomponent].between_quotes
            group[:members] << "#{hostname}\\#{username}"
          end
        end
      end

      @local_user_groups
    end

    def get_network_id
      super

      network_data = @connector.value_at('SELECT Domain, Name FROM Win32_ComputerSystem')
      @network_id[:domain] = network_data[:domain]
      @network_id[:hostname] = network_data[:name]

      @network_id
    end

    def get_network_interfaces
      super

      # retrieve ethernet interfaces
      ethernet_interfaces = @connector.values_at('SELECT Index, MACAddress, Manufacturer, NetConnectionID, NetConnectionStatus, ProductName FROM Win32_NetworkAdapter WHERE NetConnectionID IS NOT NULL')

      ethernet_interfaces.each do |interface_profile|
        h = network_interface_template

        index = interface_profile[:index]
        padded_index = '%04d' % index
        h[:is_uplink] = false
        h[:mac_address] = interface_profile[:macaddress]
        h[:model] = interface_profile[:productname]
        h[:name] = interface_profile[:netconnectionid]
        h[:status] = case interface_profile[:netconnectionstatus]
        when 1, 2; 'up'
        else; 'down'
        end
        h[:type] = 'ethernet'
        h[:vendor] = interface_profile[:manufacturer]

        # retrieve config for this interface
        interface_config = @connector.value_at("SELECT DNSServerSearchOrder, IPAddress, IPSubnet, SettingID FROM Win32_NetworkAdapterConfiguration WHERE Index = #{index}")

        guid = interface_config[:settingid]
        h[:dns_servers] = interface_config[:dnsserversearchorder]

        subnet = interface_config[:ipsubnet]

        interface_config[:ipaddress].each do |ip_address|
          h[:ip_addresses] << {:ip_address=>ip_address, :subnet=>subnet}
        end unless interface_config[:ipaddress].nil?

        cfg_keypath = NIC_CFG_KEYPATH + "\\#{padded_index}"
        
        # retrieve auto negotiate/duplex setting.  tricky to get because this is very driver-specific.
        # basically we have some known duplex values in DUPLEX_REG_VALS, then we search in the registry
        # for each value and see if it exists.  if it exists, then we dig deeper into the subkeys
        # of this NIC's driver registry key and get the translated value from the list of options
        # (found in the \Enum subkey)
        interface_driver_config = @connector.registry_values_at(cfg_keypath)
        h[:auto_negotiate] = false
        duplex_reg_value = interface_driver_config.select {|key, val| DUPLEX_REG_VALS.include?(key)}

        if duplex_reg_value.empty?
          h[:auto_negotiate] = true
          h[:duplex] = 'auto'
        else
          duplex_value = @connector.registry_values_at(cfg_keypath + "\\Ndi\\params\\#{duplex_reg_value.keys[0]}\\Enum")
          duplex_value = duplex_value.select{|key, val| key.to_s == duplex_reg_value.values[0].to_s}.values[0]

          if duplex_value =~ /auto|default/i
            h[:auto_negotiate] = true
            h[:duplex] = 'auto'
          elsif duplex_value =~ /1000|full/i
            h[:duplex] = 'full'
          elsif duplex_value =~ /half/i
            h[:duplex] = 'half'
          end
        end

        # get model/vendor ids
        hardware_ids = interface_driver_config[:matchingdeviceid].scan(/[ven|dev]_(\d{4})/i)

        h[:vendor_id] = '0x' + hardware_ids[0].join unless hardware_ids[0].nil?
        h[:model_id] = '0x' + hardware_ids[1].join unless hardware_ids[1].nil?

        # retrieve mtu
        mtu_data = @connector.registry_values_at(TCPIP_CFG_KEYPATH + "\\#{guid}")
        h[:mtu] = mtu_data[:mtu] if mtu_data.has_key?(:mtu)

        # translate the adapter guid to it's internal device name (usually prefixed with \\DEVICE)
        device_guid = @connector.registry_values_at(cfg_keypath + '\\Linkage')[:export][0].gsub(/\\/, '\\\\\\')

        adapter_name_data = @connector.value_at("SELECT InstanceName FROM MSNdis_EnumerateAdapter WHERE DeviceName = '#{device_guid}'", :root_wmi)
        internal_adapter_name = adapter_name_data[:instancename]

        # now with the internal adapter name, we can grab the connection speed.
        speed_data = @connector.value_at("SELECT NdisLinkSpeed FROM MSNdis_LinkSpeed WHERE InstanceName = '#{internal_adapter_name}'", :root_wmi)
        h[:current_speed_mbps] = speed_data[:ndislinkspeed] / 10000

        @network_interfaces << h
      end

      # retrieve fibre channel interfaces. for windows 2003, this only works if the hbaapi is
      # available, which can be installed by the fibre controller software provided by the
      # vendor, or is installed as a separate package (fcinfo from microsoft). newer versions
      # should have it built-in by default.
      fibre_interface_profiles = @connector.values_at('SELECT Attributes, InstanceName FROM MSFC_FibrePortHBAAttributes', :root_wmi)

      fibre_interfaces = @connector.values_at('SELECT InstanceName, Manufacturer, ModelDescription FROM MSFC_FCAdapterHBAAttributes', :root_wmi)

      fibre_interfaces.each do |fibre_interface|
        h = network_interface_template

        index = fibre_interface_profiles.index{|profile| profile[:instancename] == fibre_interface[:instancename]}
        profile = fibre_interface_profiles[index]

        h[:fabric_name] = profile[:fabricname].to_wwn
        
        if h[:fabric_name] == '0000000000000000'
          h[:fabric_name] = nil
          h[:status] = 'down'
        else
          h[:current_speed_mbps] = case profile[:portspeed]
            when 1; 1000
            when 2; 2000
            when 4; 10000
            when 8; 4000
            when 16; 8000
            when 32; 16000
          end
          h[:status] = 'up'
        end

        hardware_ids = fibre_interface[:instancename].scan(/[ven|dev]_(\d{4})/i)

        h[:vendor_id] = '0x' + hardware_ids[0].join if hardware_ids[0]
        h[:model_id] = '0x' + hardware_ids[1].join if hardware_ids[1]

        h[:is_uplink] = false
        h[:model] = fibre_interface[:modeldescription]
        h[:name] = "fc#{index}"
        h[:node_wwn] = profile[:nodewwn].to_wwn
        h[:port_wwn] = profile[:portwwn].to_wwn
        h[:type] = 'fibre'
        h[:vendor] = fibre_interface[:manufacturer]
        
        @network_interfaces << h
      end

      @network_interfaces
    end

    def get_operating_system
      super

      os_data = @connector.value_at('SELECT Caption, CSDVersion, InstallDate, OtherTypeDescription, Version FROM Win32_OperatingSystem')
      @operating_system[:date_installed] = DateTime.parse(os_data[:installdate])
      @operating_system[:kernel] = os_data[:version]
      @operating_system[:license_key] = get_product_key('microsoft windows')
      @operating_system[:name] = 'Microsoft Windows'
      @operating_system[:service_pack] = os_data[:csdversion]

      role_data = @connector.value_at('SELECT Roles FROM Win32_ComputerSystem')
      @operating_system[:roles] = role_data[:roles]

      os_data[:caption].gsub!(/microsoftr*|windows|(?<=server)r|\(r\)|edition|,/i, '').strip!
      edition = os_data[:othertypedescription]
      os_data[:caption].sub!(/20[0-9]*/) {|y| "#{y} #{edition}"} if edition
      
      @operating_system[:version] = os_data[:caption]

      @operating_system
    end
    
    def get_product_key(app_name, guid=nil)

      product_key = nil
      
      if app_name =~ /microsoft/i

        app_name.remove_arch

        case
        when app_name =~ /microsoft exchange/i

          debug 'attempting to retrieve ms exchange product key'

          key_path = 'SOFTWARE\Microsoft\Exchange\Setup'
          product_key = @connector.registry_values_at(key_path)[:digitalproductid]
          product_key = product_key.to_ms_product_key unless product_key.nil?

        when app_name =~ /office/i

          debug 'attempting to retrieve ms office product key'

          version_code = case
          when app_name =~ /2003/; 11
          when app_name =~ /2007|server 12/; 12
          when app_name =~ /2010/; 14
          when app_name =~ /2013/; 15
          end

          key_path = "SOFTWARE\\Microsoft\\Office\\#{version_code}.0\\Registration\\#{guid}"
          product_key = @connector.registry_values_at(key_path)[:digitalproductid]
          product_key = product_key.to_ms_product_key unless product_key.nil?

        when app_name =~ /sql server/i

          debug 'attempting to retrieve ms sqlserver product key'

          app_edition = nil

          key_path = 'SOFTWARE\Microsoft\Microsoft SQL Server'
          
          @connector.registry_subkeys_at(key_path).each do |key|

            if key =~ /mssql(\.|10|11)/i

              version_code = case
              when key =~ /_50/i; nil # express edition (use nil to avoid detection of product key)
              when key =~ /mssql\./i; 90 # 2005
              when key =~ /mssql10/i; 100 # 2008
              when key =~ /mssql11/i; 110 # 2012
              end

              if version_code
                key_path = "#{key_path}\\#{version_code}\\ProductID"
                product_key = @connector.registry_values_at(key_path)[:digitalproductid]
                product_key = product_key.to_ms_product_key unless product_key.nil?
              end
            end
          end
        
        when app_name =~ /visual studio/i

          debug 'attempting to retrieve ms visual studio product key'

          version_code = case
          when app_name =~ /2005/; 8
          when app_name =~ /2008/; 9
          when app_name =~ /2010/; 10
          when app_name =~ /2012/; 11
          end

          key_path = "SOFTWARE\\Microsoft\\VisualStudio\\#{version_code}.0\\Registration"
          product_key = @connector.registry_values_at(key_path)[:pidkey]
          product_key = product_key.scan(/.{5}/).join('-') unless product_key.nil?

        when app_name =~ /^microsoft windows$/i

          debug 'attempting to retrieve ms windows product key'

          key_path = 'SOFTWARE\Microsoft\Windows NT\CurrentVersion'
          product_key = @connector.registry_values_at(key_path)[:digitalproductid]
          product_key = product_key.to_ms_product_key unless product_key.nil?
        end

        if product_key
          debug 'product key retrieved'
        else
          debug 'product key could not be retrieved'
        end
      end

      product_key
    end

    def get_username(guid)
      username = guid
      
      user = @connector.value_at("SELECT Caption, SID FROM Win32_UserAccount WHERE SID = '#{guid}'")
      username = user[:caption] if user[:sid] == guid

      return username
    end

    private

    def concat_app_edition(app_name)
      
      case
      when app_name =~ /sql server/i
        # grab the edition (standard, enterprise, etc)
        app_edition = @connector.registry_values_at('SOFTWARE\Microsoft\Microsoft SQL Server\Setup')[:edition]

        app_name = if app_name =~ /\(64\-bit\)/i
          app_name.sub('(64-bit)', "#{app_edition} (64-bit)")
        else
          app_name + " #{app_edition}"
        end unless !app_edition
      end

      return app_name
    end
  end
end; end
