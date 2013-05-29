require 'setup_tests'

class CiscoCoreTest < BaseTestSetup
  context 'a Cisco target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::CiscoCore)
      @target.force_profiler_to(Profilers::CiscoCore)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with('show version | include (Version)').returns('Cisco')
    end

    should 'detect when a target should use the CiscoIOS profile' do
      assert_equal(Profilers::CiscoCore, @profiler.class)
    end

    context 'being scanned' do
      setup do
        @show_version_command = 'show version | include (Version|ROM|uptime|CPU|bytes of memory)'
        @show_version_data = %{
          Cisco IOS Software, Catalyst 4500 L3 Switch Software (cat4500e-IPBASEK9-M), Version 12.1(1)SG1, RELEASE SOFTWARE (fc3)
          ROM: 12.1(1r)SG1
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
            :firmware_version=>'12.1(1r)SG1',
            :model=>'WS-C4506-E',
            :memory_installed_mb=>512,
            :serial=>'FOX123456789',
            :vendor=>VENDOR_CISCO
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

          @show_interface_command = 'show interface | include (protocol|Hardware|Internet|MTU|duplex|Members)'

          # the below data is not a realistic setup, but should cover all bases as far
          # as what we would encounter when scanning a properly configured system
          @show_interface_data = "Vlan1 is up, line protocol is up
            Hardware is Ethernet SVI, address is 0000.0000.0000 (bia 0000.0000.0000)
            Internet address is 192.168.0.1/24
            MTU 1500 bytes
            Auto-duplex, 100Mb/s, link type is auto, 100BaseTX/FX"
          @show_interface_data << "\nFastEthernet1 is up, line protocol is up
            Hardware is Fast Ethernet for out of band management, address is 0000.0000.0001 (bia 0000.0000.0001)
            Internet address is 192.168.0.2/24
            MTU 1500 bytes
            Auto-duplex, Auto Speed, 100BaseTX/FX"
          @show_interface_data << "\nGigabitEthernet1/1 is administratively down, line protocol is down (disabled)
            Hardware is Gigabit Ethernet Port, address is 0000.0000.0002 (bia 0000.0000.0002)
            MTU 1500 bytes
            Full-duplex, Auto-speed, link type is auto, media type is 1000BaseLH"
          @show_interface_data << "\nPort-channel1 is up, line protocol is up (connected)
            Hardware is EtherChannel, address is 0000.0000.0005 (bia 0000.0000.0005)
            MTU 1500 bytes, BW 2000000 Kbit, DLY 10 usec,
               reliability 255/255, txload 1/255, rxload 1/255
            Full-duplex, 1000Mb/s, media type is N/A
            Members in this channel: Gi1/1"

          @mac_address_table_command = 'show mac-address-table'
          @mac_address_table_data = %{
            1   0000.0000.0010  dynamic   ip    Port-channel1
            1   0000.0000.0011  dynamic   ip    Port-channel1
          }.strip.split(/\n/)

          @show_interface_data = @show_interface_data.split(/\n/)

          @expected_ethernet_data = []
          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :auto_negotiate=>true,
            :current_speed_mbps=>100,
            :duplex=>'auto',
            :ip_addresses=>[
              {:ip_address=>'192.168.0.1', :subnet=>'255.255.255.0'}
            ],
            :mac_address=>'00:00:00:00:00:00',
            :model=>'Ethernet SVI',
            :mtu=>1500,
            :name=>'Vlan1',
            :status=>'up',
            :type=>'ethernet',
            :vendor=>VENDOR_CISCO
          })

          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :is_uplink=>true,
            :mac_address=>'00:00:00:00:00:02',
            :model=>'Gigabit Ethernet Port',
            :mtu=>1500,
            :name=>'GigabitEthernet1/1',
            :status=>'down',
            :type=>'ethernet',
            :vendor=>VENDOR_CISCO
          })

          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :current_speed_mbps=>1000,
            :duplex=>'full',
            :is_uplink=>true,
            :mac_address=>'00:00:00:00:00:05',
            :model=>'EtherChannel',
            :mtu=>1500,
            :name=>'Port-channel1',
            :status=>'up',
            :type=>'ethernet',
            :vendor=>VENDOR_CISCO
          })
        end

        should 'return ethernet interface information via #get_network_interfaces' do
          @connector.stubs(:values_at).with(@show_interface_command).returns(@show_interface_data)
          @connector.stubs(:values_at).with(@mac_address_table_command).returns(@mac_address_table_data)

          @profiler.get_network_interfaces
          assert_equal(@expected_ethernet_data, @profiler.network_interfaces)
        end
      end

      # context 'for operating system information' do
      # end

      # context 'for running processes information' do
      # end
      
    end
  end
end