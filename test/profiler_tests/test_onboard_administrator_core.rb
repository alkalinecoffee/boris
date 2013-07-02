require 'setup_tests'

class OnboardAdministratorCoreTest < BaseTestSetup
  context 'an Onboard Administrator target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::OnboardAdministratorCore)
      @target.force_profiler_to(Profilers::OnboardAdministratorCore)
      @profiler = @target.profiler
      @connector.stubs(:values_at).with('show fru').returns(['firmware version: 3'])
    end

    should 'detect when a target should use the OnboardAdministrator profile' do
      assert_equal(Profilers::OnboardAdministratorCore, @profiler.class)
    end

    context 'being scanned' do
      setup do
        @show_enclosure_command = 'show enclosure info'
        @show_enclosure_data = %{
          Enclosure Name: ENCLOSURE1
          Enclosure Type: BladeSystem c7000 Enclosure G2
          Serial Number: ABC123
        }.strip.split(/\n/)

        @show_fru_command = 'show fru'
        @show_fru_data = %{
          Onboard Administrator 1
            Model: BladeSystem c7000 DDR2 Onboard Administrator with KVM
            Manufacturer: HP
            Serial Number: OB14BP2418
            Firmware Version: 3.50
        }.strip.split(/\n/)
      end

     # context 'for file system information' do
     # end

      context 'for hardware information' do
        setup do
          @expected_data = {
            :cpu_architecture=>nil,
            :cpu_core_count=>nil,
            :cpu_model=>nil,
            :cpu_physical_count=>nil,
            :cpu_speed_mhz=>nil,
            :cpu_vendor=>nil,
            :firmware_version=>'3.50',
            :model=>'BladeSystem c7000 Enclosure G2',
            :memory_installed_mb=>nil,
            :serial=>'ABC123',
            :vendor=>VENDOR_HP
          }
        end

        should 'return hardware information via #get_hardware' do
          @connector.stubs(:values_at).with(@show_enclosure_command).returns(@show_enclosure_data)
          @connector.stubs(:values_at).with(@show_fru_command).returns(@show_fru_data)
          
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
          @expected_data = {:domain=>nil, :hostname=>'ENCLOSURE1'}
        end

        should 'return the domain and hostname via #get_network_id' do
          @connector.stubs(:values_at).with(@show_enclosure_command).returns(@show_enclosure_data)

          @profiler.get_network_id
          assert_equal(@expected_data, @profiler.network_id)
        end
      end

      context 'for network interfaces' do
        setup do
          @show_oa_network_command = 'show oa network all'
          @show_oa_network_data = %{
            Onboard Administrator #1 Network Information:
              Name: eth0

              - - - - - IPv4 Information - - - - -
              DHCP: Disabled
              IPv4 Address: 192.168.0.1
              Netmask: 255.255.255.0
              Gateway Address: 0.0.0.0

              - - - - - General Information - - - - -
              Active DNS Addresses:
                      Primary:         Not Set
                      Secondary:       Not Set
                      Tertiary:        Not Set

              MAC Address: 00:00:00:00:00:00
              Link Settings: Auto-Negotiation, 100 Mbps, Auto Duplex
              Link Status: Active

            Onboard Administrator #2 Network Information:
              Name: eth1

              - - - - - IPv4 Information - - - - -
              DHCP: Disabled
              IPv4 Address: 192.168.0.2
              Netmask: 255.255.255.0
              Gateway Address: 0.0.0.0

              - - - - - General Information - - - - -
              Active DNS Addresses:
                      Primary:         Not Set
                      Secondary:       Not Set
                      Tertiary:        Not Set

              MAC Address: 00:00:00:00:00:01
              Link Settings: Auto-Negotiation, 10 Mbps, Half Duplex
              Link Status: Not Active
          }.strip.split(/\n/)

          @expected_ethernet_data = []
          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :auto_negotiate=>true,
            :current_speed_mbps=>100,
            :duplex=>'full',
            :ip_addresses=>[
              {:ip_address=>'192.168.0.1', :subnet=>'255.255.255.0'}
            ],
            :mac_address=>'00:00:00:00:00:00',
            :model=>'Unknown Ethernet Adapter',
            :name=>'eth0',
            :status=>'up',
            :type=>'ethernet',
            :vendor=>VENDOR_HP
          })

          @expected_ethernet_data << @profiler.network_interface_template.merge({
            :mac_address=>'00:00:00:00:00:01',
            :model=>'Unknown Ethernet Adapter',
            :name=>'eth1',
            :status=>'down',
            :type=>'ethernet',
            :vendor=>VENDOR_HP
          })

        end

        should 'return ethernet interface information via #get_network_interfaces' do
          @connector.stubs(:values_at).with(@show_oa_network_command).returns(@show_oa_network_data)

          @profiler.get_network_interfaces
          assert_equal(@expected_ethernet_data, @profiler.network_interfaces)
        end
      end

      context 'for operating system information' do
        setup do
          @expected_data = {
            :date_installed=>nil,
            :features=>[],
            :kernel=>nil,
            :license_key=>nil,
            :name=>'HP Onboard Administrator',
            :roles=>[],
            :service_pack=>nil,
            :version=>'3.50'
          }
        end

        should 'return operating system information via #get_operating_system' do
          @connector.stubs(:values_at).with(@show_fru_command).returns(@show_fru_data)

          @profiler.get_operating_system
          assert_equal(@expected_data, @profiler.operating_system)
        end
        
      end

      # context 'for running processes information' do
      # end
      
    end
  end
end