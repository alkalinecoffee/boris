require 'setup_tests'

class WindowsCoreTest < ProfilerTestSetup
  context 'a Windows target' do
    setup do
      @connector = @target.connector = WMIConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::Windows)
      @target.force_profiler_to(Profilers::Windows)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with('SELECT Name FROM Win32_OperatingSystem').returns({:name=>'Windows Server 2008'})
    end

    should 'detect when a target should use the Windows profile' do
      assert_equal(Profilers::Windows, @profiler.class)
    end

    context 'being scanned' do
      setup do
      end

      context 'for file system information' do
        setup do
          @logical_disks_qry = 'SELECT FreeSpace, Name, Size FROM Win32_LogicalDisk WHERE DriveType=3'
          @logical_disks_data = [
            {:freespace=>1073741824, :name=>'C:', :size=>2147483648}
          ]

          @physical_disks_qry = 'SELECT DeviceID, Model FROM Win32_DiskDrive'
          @physical_disks_data = [
            {
              :deviceid=>'\\.\PHYSICALDRIVE0',
              :model=>'LOGICAL VOLUME SCSI Disk Device'
            }
          ]

          @partition_mapping_qry = 'SELECT Antecedent, Dependent FROM Win32_LogicalDiskToPartition'
          @partition_mapping_data = [
            {
              :antecedent=>"\\#{@target_name}\\root\\cimv2:Win32_DiskPartition.DeviceID=\"Disk #0, Partition #0\"",
              :dependent=>"\\#{@target_name}\\root\\cimv2:Win32_LogicalDisk.DeviceID=\"C:\""
            }
          ]

          @disk_partitions_qry = "SELECT Antecedent, Dependent FROM Win32_DiskDriveToDiskPartition"
          @disk_partitions_data = [
            {
              :antecedent=>"\\#{@target_name}\\root\\cimv2:Win32_DiskDrive.DeviceID=\"\\\\.\\PHYSICALDRIVE0\"",
              :dependent=>"\\#{@target_name}\\root\\cimv2:Win32_DiskPartition.DeviceID=\"Disk #0, Partition #0\""
            }
          ]

          @expected_data = [
            {
              :capacity_mb=>2048,
              :file_system=>'Disk #0, Partition #0',
              :mount_point=>'C:',
              :san_storage=>nil,
              :used_space_mb=>1024
            }
          ]
        end

        should 'return file system information via #get_file_systems' do
          @connector.stubs(:values_at).with(@logical_disks_qry).returns(@logical_disks_data)
          @connector.stubs(:values_at).with(@partition_mapping_qry).returns(@partition_mapping_data)
          @connector.stubs(:values_at).with(@physical_disks_qry).returns(@physical_disks_data)
          @connector.stubs(:values_at).with(@disk_partitions_qry).returns(@disk_partitions_data)

          @profiler.get_file_systems

          assert_equal(@expected_data, @profiler.file_systems)
        end
      end

      context 'for hardware information' do
        setup do
          @bios_qry = 'SELECT SerialNumber, SMBIOSBIOSVersion FROM Win32_BIOS'
          @bios_data = {:serialnumber=>'1234ABCD', :smbiosbiosversion=>'6.0'}

          @model_qry = 'SELECT Manufacturer, Model, TotalPhysicalMemory FROM Win32_ComputerSystem'
          @model_data = {
            :manufacturer=>'VMware, Inc.',
            :model=>'VMware Virtual Platform',
            :totalphysicalmemory=>2146861056
          }
          
          @cpu_qry = 'SELECT * FROM Win32_Processor'
          @cpu_data = [
            {
              :datawidth=>32,
              :l2cachesize=>1024,
              :manufacturer=>'AuthenticAMD',
              :maxclockspeed=>2813,
              :name=>'Dual-Core AMD Opteron(tm) Processor 8220',
              :numberofcores=>1,
              :numberoflogicalprocessors=>1
            }
          ]

          @expected_data = {
            :cpu_architecture=>32,
            :cpu_core_count=>1,
            :cpu_model=>'Dual-Core AMD Opteron(tm) Processor 8220',
            :cpu_physical_count=>1,
            :cpu_speed_mhz=>2813,
            :cpu_vendor=>'AuthenticAMD',
            :firmware_version=>'6.0',
            :model=>'VMware Virtual Platform',
            :memory_installed_mb=>2047,
            :serial=>'1234ABCD',
            :vendor=>'VMware, Inc.'
          }
        end

        should 'return hardware information via #get_hardware' do
          @connector.stubs(:value_at).with(@bios_qry).returns(@bios_data)
          @connector.stubs(:value_at).with(@model_qry).returns(@model_data)
          @connector.stubs(:values_at).with(@cpu_qry).returns(@cpu_data)

          @profiler.get_hardware

          assert_equal(@expected_data, @profiler.hardware)
        end
      end

      context 'for hosted shares' do
        setup do
          @expected_data = [{:name=>'myshare', :path=>'D:\myshare'}]
        end

        should 'return hosted share information via #get_hosted_shares' do
          @connector.stubs(:values_at).with('SELECT Name, Path FROM Win32_Share WHERE Type = 0').returns(@expected_data)
          @profiler.get_hosted_shares
          assert_equal(@expected_data, @profiler.hosted_shares)
        end
      end

      context 'for installed applications' do
        setup do
          @guid = '{4AB6A079-178B-4144-B21F-4D1AE71666A2}'
          @product_key_binary = [164, 1, 1, 0, 3, 0, 0, 0, 53, 53, 48, 52, 49, 45, 49, 56, 54, 45, 48, 49, 51, 51, 48,
            51, 53, 45, 55, 53, 55, 54, 51, 0, 151, 0, 0, 0, 88, 49, 52, 45, 50, 51, 56, 57, 54, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
          @expected_product_key = 'BBBBB-BBBBB-BBBBB-BBBBB-BBBBB'
        end

        should 'extract the product key from a binary string' do
          assert_equal(@expected_product_key, @product_key_binary.to_ms_product_key)
        end

        context 'by microsoft' do
          context 'in the sqlserver family' do
            should 'detect the product key for various sqlserver editions' do

              versions = []
              versions << {:code=>90, :instance=>'mssql.1', :name=>'Microsoft SQL Server 2005'}
              versions << {:code=>100, :instance=>'mssql10.1', :name=>'Microsoft SQL Server 2008'}
              versions << {:code=>110, :instance=>'mssql11.1', :name=>'Microsoft SQL Server 2012'}

              key_path = 'SOFTWARE\Microsoft\Microsoft SQL Server'

              versions.each do |version|
                @connector.stubs(:registry_subkeys_at).returns(["#{key_path}\\#{version[:instance]}"])
                @connector.stubs(:registry_values_at).with("#{key_path}\\#{version[:code]}\\ProductID").returns({:digitalproductid=>@product_key_binary})
                assert_equal(@expected_product_key, @profiler.get_product_key(version[:name]))
              end
            end
          end

          context 'in the visual studio family' do
            setup do
              @connector.stubs(:registry_values_at).at_least_once.returns({:pidkey=>@expected_product_key.gsub(/-/, '')})
            end

            should 'detect the product key for various Visual Studio editions' do
              assert_equal(@expected_product_key, @profiler.get_product_key('Microsoft Visual Studio 2005 Professional Edition'))
              assert_equal(@expected_product_key, @profiler.get_product_key('Microsoft Visual Studio 2008 Professional Edition'))
            end
          end

          context "in the exchange/office/windows families" do
            setup do
              @connector.stubs(:registry_values_at).at_least_once.returns({:digitalproductid=>@product_key_binary})
            end

            should 'detect the product key for various Exchange editions' do
              assert_equal(@expected_product_key, @profiler.get_product_key('Microsoft Exchange'))
            end

            should 'detect the product key for various Office and Exchange editions' do
              assert_equal(@expected_product_key, @profiler.get_product_key('Microsoft Office Professional Edition 2003', @guid))
              assert_equal(@expected_product_key, @profiler.get_product_key('Microsoft Office Project Server 12', @guid))
              assert_equal(@expected_product_key, @profiler.get_product_key('Microsoft Office SharePoint Server 2007', @guid))
              assert_equal(@expected_product_key, @profiler.get_product_key('Microsoft Office XP Professional with FrontPage', @guid))
            end

            should 'detect the product key for various Windows editions' do
              assert_equal(@expected_product_key, @profiler.get_product_key('Microsoft Windows'))
            end
          end
        end

        should 'return installed applications via #get_installed_applications' do
          key_path = Profilers::Windows::APP64_KEYPATH + '\{4AB6A079-178B-4144-B21F-4D1AE71666A2}'

          application_data = {
            :installdate=>'20120101',
            :installlocation=>'',
            :displayname=>'Microsoft SQL Server 2008 R2 Native Client',
            :publisher=>'Microsoft Corporation',
            :displayversion=>'10.50.1600.1'
          }

          expected_data = {
            :date_installed=>DateTime.parse(application_data[:installdate]),
            :install_location=>nil,
            :license_key=>nil,
            :name=>application_data[:displayname],
            :vendor=>application_data[:publisher],
            :version=>application_data[:displayversion]
          }

          @connector.stubs(:registry_subkeys_at).with(Profilers::Windows::ORACLE_KEYPATH).returns([])

          @connector.stubs(:registry_subkeys_at).with(Profilers::Windows::APP32_KEYPATH).returns([])
          @connector.stubs(:registry_subkeys_at).with(Profilers::Windows::APP64_KEYPATH).returns([key_path])

          sql_key_path = 'SOFTWARE\Microsoft\Microsoft SQL Server'
          @connector.stubs(:registry_subkeys_at).with(sql_key_path).returns(["#{sql_key_path}\\mssql10.1"])
          @connector.stubs(:registry_values_at).with("#{sql_key_path}\\100\\ProductID").returns({})
          @connector.stubs(:registry_values_at).with("#{sql_key_path}\\Setup").returns({})
          @connector.stubs(:registry_values_at).with(key_path).returns(application_data)

          @profiler.get_installed_applications

          assert_equal([expected_data], @profiler.installed_applications)
        end
      end

      context 'for installed patches' do
        should 'parse out the patches from the registry location for applications' do
          wmi_patch_data = {
            :hotfixid=>'KB456789',
            :installedby=>'SYSTEM',
            :installedon=>'1/1/2013',
            :servicepackineffect=>''
          }

          registry_patch_data = {
            :displayname=>'KB123456',
            :displayversion=>'1.0',
            :installdate=>'20120101',
            :installlocation=>'',
            :publisher=>'Microsoft Corporation'
          }
          registry_patch_key_path = "#{Profilers::Windows::APP32_KEYPATH}\\#{registry_patch_data[:displayname]}"

          expected_data = [
            {:date_installed=>DateTime.parse(wmi_patch_data[:installedon]), :installed_by=>wmi_patch_data[:installedby], :patch_code=>wmi_patch_data[:hotfixid]},
            {:date_installed=>DateTime.parse(registry_patch_data[:installdate]), :installed_by=>nil, :patch_code=>registry_patch_data[:displayname]}
          ]

          @connector.stubs(:values_at).with('SELECT Description, HotFixID, InstalledBy, InstalledOn, ServicePackInEffect FROM Win32_QuickFixEngineering').returns([wmi_patch_data])

          @connector.stubs(:registry_subkeys_at).with(Profilers::Windows::APP32_KEYPATH).returns([registry_patch_key_path])
          @connector.stubs(:registry_subkeys_at).with(Profilers::Windows::APP64_KEYPATH).returns([])
          @connector.stubs(:registry_values_at).with(registry_patch_key_path).returns(registry_patch_data)

          @profiler.get_installed_patches

          assert_equal(expected_data, @profiler.installed_patches)
        end
      end

      context 'for installed services' do
        setup do
          @service_data = [
            :name=>'Plug and Play',
            :pathname=>'C:\WINDOWS\system32\services.exe',
            :startmode=>'Auto'
          ]

          @expected_data = [{
            :name=>@service_data[0][:name],
            :install_location=>@service_data[0][:pathname],
            :start_mode=>@service_data[0][:startmode]
          }]
        end

        should 'return service information via #get_installed_services' do
          @connector.stubs(:values_at).with('SELECT Name, PathName, StartMode FROM Win32_Service').returns(@service_data)
          
          @profiler.get_installed_services
          assert_equal(@expected_data, @profiler.installed_services)
        end
      end


      context 'for local users and groups' do
        should 'allow us to detect the user name of an account from its guid via #get_username' do
          user_data = {:caption=>'username', :sid=>'S-1-1-1'}

          @connector.stubs(:value_at).with("SELECT Caption, SID FROM Win32_UserAccount WHERE SID = '#{user_data[:sid]}'").returns(user_data)

          assert_equal(user_data[:caption], @profiler.get_username(user_data[:sid]))
        end

        should 'return local user groups and accounts via #get_local_user_groups if the server is not a domain controller' do
          hostname = 'SERVER01'
          group = 'Users'
          members = ["#{hostname}\\user1", "#{hostname}\\user2"]

          wmi_member_data = [
            {:partcomponent=>"\\#{hostname}\root\cimv2:Win32_UserAccount.Domain=\"#{hostname}\",Name=\"user1\""},
            {:partcomponent=>"\\#{hostname}\root\cimv2:Win32_UserAccount.Domain=\"#{hostname}\",Name=\"user2\""}
          ]
          
          expected_data = [{:name=>group, :members=>members}]

          @target.instance_variable_set(:@network_id, {:domain=>'mydomain.com', :hostname=>hostname})
          
          @connector.stubs(:value_at).with('SELECT Roles FROM Win32_ComputerSystem').returns({:roles=>[]})
          @connector.stubs(:value_at).with('SELECT Domain, Name FROM Win32_ComputerSystem').returns({:domain=>nil, :name=>hostname})
          @connector.stubs(:values_at).with("SELECT Name FROM Win32_Group WHERE Domain = '#{hostname}'").returns([{:name=>'Users'}])
          @connector.stubs(:values_at).with("SELECT * FROM Win32_GroupUser WHERE GroupComponent = \"Win32_Group.Domain='#{hostname}',Name='#{group}'\"").returns(wmi_member_data)

          @profiler.get_local_user_groups

          assert_equal(expected_data, @profiler.local_user_groups)
        end

        should 'cache already retrieved user information #get_username' do
          guid = 'S-1-5-18'
          expected_data = {:caption=>'someuser', :sid=>guid}
          cache_data = {:guid=>guid, :username=>expected_data[:caption]}
          @connector.stubs(:value_at).with("SELECT Caption, SID FROM Win32_UserAccount WHERE SID = '#{guid}'").once.returns(expected_data)

          assert_equal(expected_data[:caption], @profiler.get_username(guid))
          assert_equal([cache_data], @profiler.cache[:users])
          assert_equal(expected_data[:caption], @profiler.get_username(guid))
        end
      end

      context 'for network identification' do
        setup do
          @expected_data = {:domain=>'mydomain.com', :hostname=>'SERVER01'}
        end

        should 'return the domain and hostname via #get_network_id' do
          @connector.stubs(:value_at).with('SELECT Domain, Name FROM Win32_ComputerSystem').returns({:domain=>@expected_data[:domain], :name=>@expected_data[:hostname]})
          @profiler.get_network_id

          assert_equal(@expected_data, @profiler.network_id)
        end
      end

      context 'for network interfaces' do
        setup do
          @expected_ethernet_data = [@profiler.network_interface_template.merge({
            :auto_negotiate=>false,
            :current_speed_mbps=>1000,
            :dns_servers=>['192.168.1.100', '192.168.1.101'],
            :duplex=>'full',
            :ip_addresses=>[{:ip_address=>'192.168.1.2', :subnet=>'255.255.255.0'}],
            :is_uplink=>false,
            :mac_address=>'01:01:01:01:01:01',
            :model=>'Intel PRO/1000',
            :model_id=>'0x1234',
            :mtu=>1400,
            :name=>'Local Area Connection',
            :status=>'up',
            :type=>'ethernet',
            :vendor=>'Intel Corp.',
            :vendor_id=>'0x1234'
          })]

          @expected_fibre_data = @profiler.network_interface_template.merge({
            :current_speed_mbps=>4000,
            :fabric_name=>'00000000aaaaaaaa',
            :is_uplink=>false,
            :model=>'QLogic Fibre Channel Adapter',
            :model_id=>'0x1234',
            :name=>'fc0',
            :node_wwn=>'00000000aaaaaaaa',
            :port_wwn=>'00000000aaaaaaaa',
            :status=>'up',
            :type=>'fibre',
            :vendor=>'QLogic Corp.',
            :vendor_id=>'0x1234'
          })
        end

        should 'return ethernet interface information via #get_network_interfaces' do

          expected_ethernet_data = @expected_ethernet_data[0]
          
          @connector.stubs(:values_at).with('SELECT InstanceName, Manufacturer, ModelDescription FROM MSFC_FCAdapterHBAAttributes', :root_wmi).returns([])
          @connector.stubs(:values_at).with('SELECT Attributes, InstanceName FROM MSFC_FibrePortHBAAttributes', :root_wmi).returns([])

          ethernet_guid = '{1234ABCD}'
          nic_keypath = Profilers::Windows::NIC_CFG_KEYPATH
          ethernet_data = [{
            :index=>1,
            :macaddress=>expected_ethernet_data[:mac_address],
            :manufacturer=>expected_ethernet_data[:vendor],
            :netconnectionid=>expected_ethernet_data[:name],
            :netconnectionstatus=>2,
            :productname=>expected_ethernet_data[:model]
          }]

          @connector.stubs(:values_at).with('SELECT Index, MACAddress, Manufacturer, NetConnectionID, NetConnectionStatus, ProductName FROM Win32_NetworkAdapter WHERE NetConnectionID IS NOT NULL').returns(ethernet_data)

          adapter_config_data = {
            :dnsserversearchorder=>expected_ethernet_data[:dns_servers],
            :ipaddress=>expected_ethernet_data[:ip_addresses].collect{|ip| ip[:ip_address]},
            :ipsubnet=>expected_ethernet_data[:ip_addresses].collect{|ip| ip[:subnet]}[0],
            :settingid=>ethernet_guid
          }
          @connector.stubs(:value_at).with("SELECT DNSServerSearchOrder, IPAddress, IPSubnet, SettingID FROM Win32_NetworkAdapterConfiguration WHERE Index = #{ethernet_data[0][:index]}").returns(adapter_config_data)

          enum_adapter_data = {:devicename=>"\\DEVICE\\#{ethernet_guid}", :instancename=>expected_ethernet_data[:model]}

          nic_cfg_path = nic_keypath + "\\0001"

          @connector.stubs(:registry_values_at).with(nic_cfg_path + '\\Linkage').returns(:export=>[enum_adapter_data[:devicename]])
          @connector.stubs(:registry_values_at).with(nic_cfg_path).returns({:matchingdeviceid=>'pci\\ven_1234&dev_1234', :speedduplex=>1})
          @connector.stubs(:registry_subkeys_at).with(nic_cfg_path + "\\Ndi\\params").returns([nic_cfg_path + '\\SpeedDuplex'])
          @connector.stubs(:registry_values_at).with(nic_cfg_path + "\\Ndi\\params\\speedduplex\\Enum").returns({'1'.to_sym=>'1000Mbps/Full Duplex'})

          @connector.stubs(:value_at).with("SELECT InstanceName FROM MSNdis_EnumerateAdapter WHERE DeviceName = '#{enum_adapter_data[:devicename].gsub(/\\/, '\\\\\\')}'", :root_wmi).returns(enum_adapter_data)
          linkspeed_data = {:instancename=>expected_ethernet_data[:model], :ndislinkspeed=>10000000}
          @connector.stubs(:value_at).with("SELECT NdisLinkSpeed FROM MSNdis_LinkSpeed WHERE InstanceName = '#{expected_ethernet_data[:model]}'", :root_wmi).returns(linkspeed_data)

          @connector.stubs(:registry_values_at).with(Profilers::Windows::TCPIP_CFG_KEYPATH + "\\#{ethernet_guid}").returns({:mtu=>1400})

          @profiler.get_network_interfaces
          assert_equal(@expected_ethernet_data, @profiler.network_interfaces)
        end

        should 'return fibre channel interface information via #get_network_interfaces' do
          @connector.stubs(:values_at).with('SELECT Index, MACAddress, Manufacturer, NetConnectionID, NetConnectionStatus, ProductName FROM Win32_NetworkAdapter WHERE NetConnectionID IS NOT NULL').returns([])

          hba_data = {
            :instancename=>'pci\\ven_1234&dev_1234',
            :manufacturer=>@expected_fibre_data[:vendor],
            :modeldescription=>@expected_fibre_data[:model]
          }

          wwn = [0, 0, 0, 0, 170, 170, 170, 170]
          hba_profile = {
            :fabricname=>wwn,
            :instancename=>hba_data[:instancename],
            :portspeed=>8,
            :nodewwn=>wwn,
            :portwwn=>wwn
          }

          @connector.stubs(:values_at).with('SELECT InstanceName, Manufacturer, ModelDescription FROM MSFC_FCAdapterHBAAttributes', :root_wmi).returns([hba_data])

          @connector.stubs(:values_at).with("SELECT Attributes, InstanceName FROM MSFC_FibrePortHBAAttributes", :root_wmi).returns([hba_profile])

          @profiler.get_network_interfaces

          assert_equal([@expected_fibre_data], @profiler.network_interfaces)
        end
      end

      context 'for operating system information' do
        setup do
          @os_data = {
            :caption=>'Microsoft(R) Windows(R) Server 2003, Standard Edition',
            :csdversion=>'Service Pack 2',
            :installdate=>'20130101000000.000000-000',
            :othertypedescription=>'R2',
            :roles=>[],
            :version=>'5.2.3790'
          }

          product_key_binary = [164, 1, 1, 0, 3, 0, 0, 0, 53, 53, 48, 52, 49, 45, 49, 56, 54, 45, 48, 49, 51, 51, 48,
            51, 53, 45, 55, 53, 55, 54, 51, 0, 151, 0, 0, 0, 88, 49, 52, 45, 50, 51, 56, 57, 54, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 255, 223, 75, 219, 238, 3, 102, 3, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 148, 135, 143, 209]

          @connector.stubs(:value_at).with('SELECT Roles FROM Win32_ComputerSystem').returns(:roles=>[])
          @connector.stubs(:value_at).with('SELECT Caption, CSDVersion, InstallDate, OtherTypeDescription, Version FROM Win32_OperatingSystem').returns(@os_data)
          @connector.stubs(:registry_values_at).with('SOFTWARE\Microsoft\Windows NT\CurrentVersion').returns({:digitalproductid=>product_key_binary})

          @expected_data = {
            :date_installed=>DateTime.parse(@os_data[:installdate]),
            :features=>[],
            :kernel=>@os_data[:version],
            :license_key=>nil,
            :name=>'Microsoft Windows',
            :roles=>@os_data[:roles],
            :service_pack=>@os_data[:csdversion],
            :version=>'Server 2003 R2 Standard'
          }
        end

        should 'return operating system information via #get_operating_system' do
          @profiler.get_operating_system
          assert_equal(@expected_data, @profiler.operating_system)
        end
      end

      context 'for running processes information' do
        setup do
          @process_data = [
            :commandline=>'myscript',
            :kernelmodetime=>5000000,
            :usermodetime=>5000000,
            :creationdate=>'20130101000000.000000-240'
          ]

          @expected_data = [{
            :command=>@process_data[0][:commandline],
            :cpu_time=>'00-00:00:01',
            :date_started=>DateTime.strptime(@process_data[0][:creationdate], '%Y%m%d%H%M%S.%N%z')
          }]
        end

        should 'return process information via #get_running_processes' do
          @connector.stubs(:values_at).with('SELECT CommandLine, CreationDate, KernelModeTime, UserModeTime FROM Win32_Process').returns(@process_data)
          
          @profiler.get_running_processes
          assert_equal(@expected_data, @profiler.get_running_processes)
        end
      end

    end
  end
end