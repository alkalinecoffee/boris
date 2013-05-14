require 'setup_tests'

class CiscoCoreTest < ProfilerTestSetup
  context 'a Cisco target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::Cisco)
      @target.force_profiler_to(Profilers::Cisco)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with('show version').returns('Cisco')
    end

    should 'detect when a target should use the CiscoIOS profile' do
      assert_equal(Profilers::Cisco, @profiler.class)
    end

    context 'being scanned' do
      setup do
        @show_version_command = 'show version | include (Version|uptime|CPU|bytes of memory)'
        @show_version_data = %{
          Cisco IOS Software, Catalyst 4500 L3 Switch Software (cat4500e-IPBASEK9-M), Version 12.1(1)SG1, RELEASE SOFTWARE (fc3)
          ciscoswitch1 uptime is 1 minute
          cisco WS-C4506-E (MPC8548) processor (revision 9) with 524288K bytes of memory.
          MPC8548 CPU at 1GHz, Supervisor 6L-E
        }.strip.split(/\n/)
      end

     # context 'for file system information' do
     # end

      context 'for hardware information' do
        setup do
          @hardware_command = 'show idprom chassis | include (OEM|Product|Serial Number)'
          @hardware_data = %{
            OEM String = Cisco
            Product Number = WS-C4506-E
            Serial Number = FOX123456789
          }.strip.split(/\n/)

          @expected_data = {
            :cpu_architecture=>nil,
            :cpu_core_count=>nil,
            :cpu_model=>'MPC8548',
            :cpu_physical_count=>1,
            :cpu_speed_mhz=>1000,
            :cpu_vendor=>nil,
            :firmware_version=>'12.1(1)SG1',
            :model=>'WS-C4506-E',
            :memory_installed_mb=>512,
            :serial=>'FOX123456789',
            :vendor=>'Cisco Systems, Inc.'
          }
        end

        should 'return hardware information via #get_hardware' do
          @connector.stubs(:values_at).with(@show_version_command).returns(@show_version_data)
          @connector.stubs(:values_at).with(@hardware_command).returns(@hardware_data)
          
          @profiler.get_hardware
          assert_equal(@expected_data, @profiler.hardware)
        end
      end

      # context 'for hosted shares' do
      # end

      # context 'for installed applications' do
      # end

      # context 'for installed patches' do
      # end

      # context 'for installed services' do
      # end

      # context 'for local users and groups' do
      # end

      context 'for network identification' do
        setup do
          @expected_data = {:domain=>nil, :hostname=>'ciscoswitch1'}
        end

        should 'return the domain and hostname via #get_network_id' do
          @connector.stubs(:values_at).with(@show_version_command).returns(@show_version_data)

          @profiler.get_network_id
          assert_equal(@expected_data, @profiler.network_id)
        end
      end

      context 'for network interfaces' do
        setup do

          @interface_command = 'show interface summary | include (Vlan|Ethernet)'
          @interface_list = %{
            Vlan1                    0     0    0     0     0    0     0    0    0
          * Vlan16                   0     0    0     0     0    0     0    0    0
          * FastEthernet1            0     0    0     0     0    0     0    0    0
            TenGigabitEthernet1/1    0     0    0     0     0    0     0    0    0
            TenGigabitEthernet1/2    0     0    0     0     0    0     0    0    0
            GigabitEthernet1/3       0     0    0     0     0    0     0    0    0
            GigabitEthernet1/4       0     0    0     0     0    0     0    0    0
          }.strip.split(/\n/)


      #     @dns_command = 'list sys dns'
      #     @dns_data = %q{
      #       sys dns {
      #         name-servers { 192.168.1.253 192.168.1.254 }
      #       }
      #     }.strip.split(/\n/)
          
      #     @dns_servers = ['192.168.1.253', '192.168.1.254']
          
      #     @interface_command = 'list net interface all-properties'
      #     @interface_data = %q{
      #       net interface 1.1 {
      #         mac-address 0:0:0:1:1:1
      #       }
      #       net interface 1.2 {
      #         mac-address 0:0:0:1:1:2
      #       }
      #       net interface mgmt {
      #         mac-address 0:0:0:1:2:1
      #       }
      #     }.strip.split(/\n/)

      #     @interface_properties_command = 'show net interface all-properties field-fmt'
      #     @interface_properties_data = %q{
      #       net interface mgmt {
      #         media-active none
      #         status disabled
      #         trunk-name none
      #       }
      #       net interface 1.1 {
      #         media-active 1000T-FD
      #         status up
      #         trunk-name none
      #       }
      #       net interface 1.2 {
      #         media-active 100T-HD
      #         status up
      #         trunk-name TRUNK
      #       }
      #     }.strip.split(/\n/)

      #     @vlan_command = 'list net vlan'
      #     @vlan_data = %q{
      #       net vlan vlan1 {
      #         interfaces {
      #             1.1 { }
      #         }
      #       }
      #       net vlan vlan2 {
      #         interfaces {
      #             TRUNK {
      #             }
      #         }
      #       }
      #     }.strip.split(/\n/)

      #     @net_self_command = 'show running-config net self all-properties'
      #     @net_self_data = %q{
      #       net self 192.168.1.2/24 {
      #         allow-service default
      #         vlan vlan1
      #       }
      #       net self 192.168.1.3/24 {
      #         allow-service default
      #         vlan vlan1
      #       }
      #       net self 192.168.1.4 {
      #         address 192.168.1.4/24
      #         allow-service all
      #         vlan vlan2
      #       }
      #       net self OTHER_ID {
      #         address 192.168.1.5/24
      #         allow-service {
      #           default
      #         }
      #         vlan vlan2
      #       }
      #     }.strip.split(/\n/)

      #     @expected_ethernet_data = []

      #     @expected_ethernet_data << @profiler.network_interface_template.merge({
      #       :current_speed_mbps=>1000,
      #       :dns_servers=>@dns_servers,
      #       :duplex=>'full',
      #       :ip_addresses=>[
      #         {:ip_address=>'192.168.1.2', :subnet=>'255.255.255.0'},
      #         {:ip_address=>'192.168.1.3', :subnet=>'255.255.255.0'}
      #       ],
      #       :mac_address=>'00:00:00:01:01:01',
      #       :model=>'Unknown Ethernet Adapter',
      #       :name=>'1.1',
      #       :status=>'up',
      #       :type=>'ethernet',
      #       :vendor=>'F5 Networks, Inc.'
      #     })

      #     @expected_ethernet_data << @expected_ethernet_data[0].merge({
      #       :current_speed_mbps=>100,
      #       :duplex=>'half',
      #       :ip_addresses=>[
      #         {:ip_address=>'192.168.1.4', :subnet=>'255.255.255.0'},
      #         {:ip_address=>'192.168.1.5', :subnet=>'255.255.255.0'}
      #       ],
      #       :mac_address=>'00:00:00:01:01:02',
      #       :name=>'1.2'
      #     })

      #     @expected_ethernet_data << @profiler.network_interface_template.merge({
      #       :mac_address=>'00:00:00:01:02:01',
      #       :model=>'Unknown Ethernet Adapter',
      #       :name=>'mgmt',
      #       :status=>'down',
      #       :type=>'ethernet',
      #       :vendor=>'F5 Networks, Inc.'
      #     })
        end

      #   should 'return ethernet interface information via #get_network_interfaces' do
      #     @connector.stubs(:values_at).with(@dns_command).returns(@dns_data)
      #     @connector.stubs(:values_at).with(@interface_command).returns(@interface_data)
      #     @connector.stubs(:values_at).with(@interface_properties_command).returns(@interface_properties_data)
      #     @connector.stubs(:values_at).with(@vlan_command).returns(@vlan_data)
      #     @connector.stubs(:values_at).with(@net_self_command).returns(@net_self_data)

      #     @profiler.get_network_interfaces
      #     assert_equal(@expected_ethernet_data, @profiler.network_interfaces)
      #   end
      end

      context 'for operating system information' do
        setup do
          @expected_data = {
            :date_installed=>nil,
            :features=>[],
            :kernel=>nil,
            :license_key=>nil,
            :name=>'Cisco IOS',
            :roles=>[],
            :service_pack=>nil,
            :version=>'12.1(1)SG1'
          }
        end

        should 'return operating system information via #get_operating_system' do
          @connector.stubs(:values_at).with(@show_version_command).returns(@show_version_data)

          @profiler.get_operating_system
          assert_equal(@expected_data, @profiler.operating_system)
        end
      end
    end
  end
end