require 'setup_tests'

class CiscoNXOSCoreTest < BaseTestSetup
  context 'a Cisco NXOS target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::CiscoNXOSCore)
      @target.force_profiler_to(Profilers::CiscoNXOSCore)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with('show version | include Software').returns('Cisco Nexus')
    end

    should 'detect when a target should use the CiscoNXOS profile' do
      assert_equal(Profilers::CiscoNXOSCore, @profiler.class)
    end

    context 'being scanned' do
      setup do
        @show_version_command = 'show version | grep -i "bios:\|system version\|chassis\|memory\|device"'
        @show_version_data = %{
          BIOS:      version 3.0.0
          cisco Nexus5596 Chassis ("O2 ABCD1234/Modular Supervisor")
          Intel(R) Xeon(R) CPU         with 8263872 kB of memory.
          Device name: nexus1
          System version: 5.1(1)N1(1)
        }.strip.split(/\n/)
      end

     # context 'for file system information' do
     # end

      context 'for hardware information' do
        setup do
          @hardware_command = 'show sprom backplane | grep Product\|Serial'
          @hardware_data = %{
            Product Number : N5K-C5596UP
            Serial Number  : ABCD1234
          }.strip.split(/\n/)

          @expected_data = {
            :cpu_architecture=>nil,
            :cpu_core_count=>nil,
            :cpu_model=>'Intel(R) Xeon(R) CPU',
            :cpu_physical_count=>1,
            :cpu_speed_mhz=>nil,
            :cpu_vendor=>nil,
            :firmware_version=>'3.0.0',
            :model=>'N5K-C5596UP',
            :memory_installed_mb=>8070,
            :serial=>'ABCD1234',
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
          @expected_data = {:domain=>nil, :hostname=>'nexus1'}
        end

        should 'return the domain and hostname via #get_network_id' do
          @connector.stubs(:values_at).with(@show_version_command).returns(@show_version_data)

          @profiler.get_network_id
          assert_equal(@expected_data, @profiler.network_id)
        end
      end

      context 'for network interfaces' do
        setup do
          @show_interface_command = 'show interface | grep "is up\|is down\|Hardware\|Internet\|MTU\|duplex\|Members"'

          # the below data is not a realistic setup, but should cover all bases as far
          # as what we would encounter when scanning a properly configured system
          @show_interface_data = []
          @show_interface_data << "Vlan1 is up, line protocol is up
            Hardware is EtherSVI, address is  0000.0000.0000
            Internet address is 192.168.0.1/24
            MTU 1500 bytes, BW 1000000 Kbit, DLY 10 usec"
          @show_interface_data << "mgmt0 is up
            Hardware: GigabitEthernet, address: 0000.0000.0001 (bia 0000.0000.0001)
            Internet address is 192.168.0.2/24
            MTU 1500 bytes, BW 1000000 Kbit, DLY 10 usec
            full-duplex, 1000 Mb/s"
          @show_interface_data << "Ethernet1/1 is down (SFP not inserted)
            Hardware: 1000/10000 Ethernet, address: 0000.0000.0002 (bia 0000.0000.0002)
            MTU 1500 bytes, BW 10000000 Kbit, DLY 10 usec
            auto-duplex, 10 Gb/s, media type is 10G"
          @show_interface_data << "port-channel1 is up
            Hardware: Port-Channel, address: 0000.0000.0005 (bia 0000.0000.0005)
            MTU 1500 bytes, BW 20000000 Kbit, DLY 10 usec
            full-duplex, 10 Gb/s
            Members in this channel: Eth1/1"

          @mac_address_table_command = 'show mac-address-table'
          @mac_address_table_data = %{
            + 4        0000.0000.0010    dynamic   0          F    F  Po1
            + 4        0000.0000.0011    dynamic   0          F    F  Po1
          }.strip.split(/\n/)

          @expected_ethernet_data = []
          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :current_speed_mbps=>nil,
            :ip_addresses=>[
              {:ip_address=>'192.168.0.1', :subnet=>'255.255.255.0'}
            ],
            :mac_address=>'00:00:00:00:00:00',
            :model=>'EtherSVI',
            :mtu=>1500,
            :name=>'Vlan1',
            :status=>'up',
            :type=>'ethernet',
            :vendor=>VENDOR_CISCO
          })

          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :is_uplink=>true,
            :mac_address=>'00:00:00:00:00:02',
            :model=>'1000/10000 Ethernet',
            :mtu=>1500,
            :name=>'Ethernet1/1',
            :status=>'down',
            :type=>'ethernet',
            :vendor=>VENDOR_CISCO
          })

          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :current_speed_mbps=>10000,
            :duplex=>'full',
            :is_uplink=>true,
            :mac_address=>'00:00:00:00:00:05',
            :model=>'Port-Channel',
            :mtu=>1500,
            :name=>'port-channel1',
            :status=>'up',
            :type=>'port-channel',
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