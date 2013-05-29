require 'setup_tests'

class BigIPCoreTest < BaseTestSetup
  context 'an F5 BIG-IP target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::BigIPCore)
      @target.force_profiler_to(Profilers::BigIPCore)
      @profiler = @target.profiler
      @connector.stubs(:values_at).with('show sys version').returns(['Sys::Version'])
    end

    should 'detect when a target should use the BigIPCore profile' do
      assert_equal(Profilers::BigIPCore, @profiler.class)
    end

    context 'being scanned' do
      setup do
        @license_command = 'show sys license'
        @license_data = %{
          Sys::License
          Registration key      ABC-123
          Platform ID           D100
          Active Modules
            Software 1 (ABC-123)
            Software 2 (ABC-123)
        }.strip.split(/\n/)

        @operating_system_command = 'show sys version'
        @operating_system_data = %q{
          Sys::Version
          Main Package

            Product  BIG-IP
            Version  10.2.1
            Build    100.0
            Edition  Hotfix HF3
            Date     Sat Apr 6 00:00:00 EDT 2013

          Hotfix List
          ID00000  ID00001  ID00002  ID00003  ID00004  ID00005
          ID00006
        }.strip.split(/\n/)
      end

     # context 'for file system information' do
     # end

      context 'for hardware information' do
        setup do
          @hardware_command = 'show sys hardware'
          @hardware_data = %q{
            Sys::Hardware
            Hardware Version Information
              Name        cpld
              Type        pic
              Model       F5 cpld
              Parameters  --                       --
                          version                  0xa

              Name        cpus
              Model       Dual-Core AMD Opteron(tm) Processor 2214 HE
              Parameters  --          --
                          cores       2   (cores/cpu:2)
                          cpu MHz     2200.000

            Platform
              Name           BIG-IP 6900F
              BIOS Revision  OBJ-0001-01 - Build: 10000

            System Information
              Type                       D001
              Chassis Serial             f5-abc-123
          }.strip.split(/\n/)

          @cpu_mem_command = 'show sys host'
          @cpu_mem_data = %q{
            Sys::Host: 0
            --------------------------------
            CPU Count         2
            Active CPU Count  2

            Memory (bytes)
              Total        3.8G
          }.strip.split(/\n/)

          @expected_data = {
            :cpu_architecture=>nil,
            :cpu_core_count=>2,
            :cpu_model=>'Dual-Core AMD Opteron(tm) Processor 2214 HE',
            :cpu_physical_count=>2,
            :cpu_speed_mhz=>2200,
            :cpu_vendor=>nil,
            :firmware_version=>'OBJ-0001-01 - Build: 10000',
            :model=>'BIG-IP 6900F (D100)',
            :memory_installed_mb=>3891,
            :serial=>'f5-abc-123',
            :vendor=>'F5 Networks, Inc.'
          }
        end

        should 'return hardware information via #get_hardware' do
          @connector.stubs(:values_at).with(@license_command).returns(@license_data)
          @connector.stubs(:values_at).with(@hardware_command).returns(@hardware_data)
          @connector.stubs(:values_at).with(@cpu_mem_command).returns(@cpu_mem_data)

          @profiler.get_hardware
          assert_equal(@expected_data, @profiler.hardware)
        end
      end

      # context 'for hosted shares' do
      # end

      context 'for installed applications' do
        setup do
          @expected_data = [
            {
              :date_installed=>nil,
              :install_location=>nil,
              :license_key=>'ABC-123',
              :name=>'Software 1',
              :vendor=>'F5 Networks, Inc.',
              :version=>nil
            },
            {
              :date_installed=>nil,
              :install_location=>nil,
              :license_key=>'ABC-123',
              :name=>'Software 2',
              :vendor=>'F5 Networks, Inc.',
              :version=>nil
            },
          ]
        end

        should 'return installed applications via #get_installed_applications' do
          @connector.stubs(:values_at).with(@license_command).returns(@license_data)

          @profiler.get_installed_applications
          assert_equal(@expected_data, @profiler.installed_applications)
        end
      end

      context 'for installed patches' do
        setup do
          @expected_data = []
          %w{ID00000 ID00001 ID00002 ID00003 ID00004 ID00005 ID00006}.each do |patch|
            @expected_data << {:date_installed=>nil, :installed_by=>nil, :patch_code=>patch}
          end
        end

        should 'return installed patches via #get_installed_patches' do
          @connector.stubs(:values_at).with(@operating_system_command).returns(@operating_system_data)
          @profiler.get_installed_patches
          assert_equal(@expected_data, @profiler.installed_patches)
        end
      end

      # context 'for installed services' do
      # end


      # context 'for local users and groups' do
      # end

      context 'for network identification' do
        setup do
          @hostname_command = 'list sys global-settings hostname'
          @hostname_data = %q{
            sys global-settings {
              hostname BIGIP.mydomain.com
            }
          }.strip.split(/\n/)
          @expected_data = {:domain=>'mydomain.com', :hostname=>'BIGIP'}
        end

        should 'return the domain and hostname via #get_network_id' do
          @connector.stubs(:values_at).with(@hostname_command).returns(@hostname_data)
          @profiler.get_network_id
          assert_equal(@expected_data, @profiler.network_id)
        end
      end

      context 'for network interfaces' do
        setup do
          @dns_command = 'list sys dns'
          @dns_data = %q{
            sys dns {
              name-servers { 192.168.1.253 192.168.1.254 }
            }
          }.strip.split(/\n/)
          
          @dns_servers = ['192.168.1.253', '192.168.1.254']
          
          @interface_command = 'list net interface all-properties'
          @interface_data = %q{
            net interface 1.1 {
              mac-address 0:0:0:1:1:1
            }
            net interface 1.2 {
              mac-address 0:0:0:1:1:2
            }
            net interface mgmt {
              mac-address 0:0:0:1:2:1
            }
          }.strip.split(/\n/)

          @interface_properties_command = 'show net interface all-properties field-fmt'
          @interface_properties_data = %q{
            net interface mgmt {
              media-active none
              status disabled
              trunk-name none
            }
            net interface 1.1 {
              media-active 1000T-FD
              status up
              trunk-name none
            }
            net interface 1.2 {
              media-active 100T-HD
              status up
              trunk-name TRUNK
            }
          }.strip.split(/\n/)

          @vlan_command = 'list net vlan'
          @vlan_data = %q{
            net vlan vlan1 {
              interfaces {
                  1.1 { }
              }
            }
            net vlan vlan2 {
              interfaces {
                  TRUNK {
                  }
              }
            }
          }.strip.split(/\n/)

          @net_self_command = 'show running-config net self all-properties'
          @net_self_data = %q{
            net self 192.168.1.2/24 {
              allow-service default
              vlan vlan1
            }
            net self 192.168.1.3/24 {
              allow-service default
              vlan vlan1
            }
            net self 192.168.1.4 {
              address 192.168.1.4/24
              allow-service all
              vlan vlan2
            }
            net self OTHER_ID {
              address 192.168.1.5/24
              allow-service {
                default
              }
              vlan vlan2
            }
          }.strip.split(/\n/)

          @expected_ethernet_data = []

          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :current_speed_mbps=>1000,
            :dns_servers=>@dns_servers,
            :duplex=>'full',
            :ip_addresses=>[
              {:ip_address=>'192.168.1.2', :subnet=>'255.255.255.0'},
              {:ip_address=>'192.168.1.3', :subnet=>'255.255.255.0'}
            ],
            :mac_address=>'00:00:00:01:01:01',
            :model=>'Unknown Ethernet Adapter',
            :name=>'1.1',
            :status=>'up',
            :type=>'ethernet',
            :vendor=>'F5 Networks, Inc.'
          })

          @expected_ethernet_data << @expected_ethernet_data[0].merge({
            :current_speed_mbps=>100,
            :duplex=>'half',
            :ip_addresses=>[
              {:ip_address=>'192.168.1.4', :subnet=>'255.255.255.0'},
              {:ip_address=>'192.168.1.5', :subnet=>'255.255.255.0'}
            ],
            :mac_address=>'00:00:00:01:01:02',
            :name=>'1.2'
          })

          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :mac_address=>'00:00:00:01:02:01',
            :model=>'Unknown Ethernet Adapter',
            :name=>'mgmt',
            :status=>'down',
            :type=>'ethernet',
            :vendor=>'F5 Networks, Inc.'
          })
        end

        should 'return ethernet interface information via #get_network_interfaces' do
          @connector.stubs(:values_at).with(@dns_command).returns(@dns_data)
          @connector.stubs(:values_at).with(@interface_command).returns(@interface_data)
          @connector.stubs(:values_at).with(@interface_properties_command).returns(@interface_properties_data)
          @connector.stubs(:values_at).with(@vlan_command).returns(@vlan_data)
          @connector.stubs(:values_at).with(@net_self_command).returns(@net_self_data)

          @profiler.get_network_interfaces
          assert_equal(@expected_ethernet_data, @profiler.network_interfaces)
        end
      end

      context 'for operating system information' do
        setup do
          @expected_data = {
            :date_installed=>nil,
            :features=>[],
            :kernel=>'100.0',
            :license_key=>'ABC-123',
            :name=>'BIG-IP',
            :roles=>[],
            :service_pack=>'Hotfix HF3',
            :version=>'10.2.1'
          }
        end

        should 'return operating system information via #get_operating_system' do
          @connector.stubs(:values_at).with(@license_command).returns(@license_data)
          @connector.stubs(:values_at).with(@operating_system_command).returns(@operating_system_data)
          @profiler.get_operating_system
          assert_equal(@expected_data, @profiler.operating_system)
        end
      end

      # context 'for running processes information' do
      # end
    end
  end
end