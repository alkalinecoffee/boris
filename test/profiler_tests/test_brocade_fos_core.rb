require 'setup_tests'

class BrocadeFOSCoreTest < BaseTestSetup
  context 'an Brocade FOS target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::BrocadeFOSCore)
      @target.force_profiler_to(Profilers::BrocadeFOSCore)
      @profiler = @target.profiler
      @connector.stubs(:values_at).with('version').returns(['Fabric OS'])
    end

    should 'detect when a target should use the BrocadeFOS profile' do
      assert_equal(Profilers::BrocadeFOSCore, @profiler.class)
    end

    context 'being scanned' do
      setup do
        @version_command = 'version'
        @version_data = %{
          Kernel:     2.2.0.0
          Fabric OS:  v5.0.0b
          Made on:    Tue Jan 1 00:00:00 2013
          Flash:      Tue Jan 1 00:00:00 2013
          BootProm:   1.0.0
        }.strip.split(/\n/)

        @switchshow_command = 'switchshow'
        @switchshow_data = %{
          switchName:     SWITCH1
          switchType:     26.1
          switchWwn:      00:00:00:00:00:00:00:00

          Index Slot Port Address Media Speed State     Proto
          ==============================================
            0   1   0   e00000   id    N8   Online      FC  E-Port  00:00:00:00:00:00:00:01 "SANSWITCH1" (upstream)
            1   1   1   e00001   id     2   Online      FC  E-Port  00:00:00:00:00:00:00:02 "SANSWITCH2"
            2   1   2   e00002   id    N8   No_Light    FC
        }.strip.split(/\n/)
      end

     # context 'for file system information' do
     # end

      context 'for hardware information' do
        setup do
          @serial_command = 'chassisshow | grep "Factory Serial"'
          @serial_data = 'Factory Serial Num: ABC123'

          @expected_data = {
            :cpu_architecture=>nil,
            :cpu_core_count=>nil,
            :cpu_model=>nil,
            :cpu_physical_count=>nil,
            :cpu_speed_mhz=>nil,
            :cpu_vendor=>nil,
            :firmware_version=>'1.0.0',
            :model=>'Brocade 3850 Switch',
            :memory_installed_mb=>nil,
            :serial=>'ABC123',
            :vendor=>VENDOR_BROCADE
          }
        end

        should 'return hardware information via #get_hardware' do
          @connector.stubs(:value_at).with(@serial_command).returns(@serial_data)
          @connector.stubs(:values_at).with(@switchshow_command).returns(@switchshow_data)
          @connector.stubs(:values_at).with(@version_command).returns(@version_data)

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
          @expected_data = {:domain=>nil, :hostname=>'SWITCH1'}
        end

        should 'return the domain and hostname via #get_network_id' do
          @connector.stubs(:values_at).with(@switchshow_command).returns(@switchshow_data)

          @profiler.get_network_id
          assert_equal(@expected_data, @profiler.network_id)
        end
      end

      context 'for network interfaces' do
        setup do
          @ifmodeshow_command = 'ifmodeshow "eth0"'
          @ifmodeshow_data = %{
            Link mode: negotiated 100baseTx-HD, link ok
            MAC Address: 00:00:00:00:00:00
          }.strip.split(/\n/)

          @ipaddr_command = 'ipaddrshow'
          @ipaddr_data = %{
            SWITCH
            Ethernet IP Address: 192.168.1.1
            Ethernet Subnetmask: 255.255.255.0
            Gateway IP Address: none
            DHCP: Off
          }.strip.split(/\n/)

          @expected_interface_data = [@profiler.network_interface_template.merge({
            :auto_negotiate=>true,
            :current_speed_mbps=>100,
            :ip_addresses=>[
              {:ip_address=>'192.168.1.1', :subnet=>'255.255.255.0'}
            ],
            :mac_address=>'00:00:00:00:00:00',
            :model=>'Unknown Ethernet Adapter',
            :name=>'eth0',
            :status=>'up',
            :type=>'ethernet',
            :vendor=>VENDOR_BROCADE
          })]

          @fibre_portshow_data = []
          @fibre_portshow_data << {
            :index=>'1/0',
            :portshow_data=>'
              portWwn: 00:00:00:00:00:00:00:01
              portWwn of device(s) connected:
              00:00:00:00:00:00:01:00
              00:00:00:00:00:00:02:00
              Distance:  normal'.strip
          }
          @fibre_portshow_data << {
            :index=>'1/1',
            :portshow_data=>'
              portWwn: 00:00:00:00:00:00:00:02
              portWwn of device(s) connected:
              00:00:00:00:00:00:01:00
              Distance:  normal'.strip
          }
          @fibre_portshow_data << {
            :index=>'1/2',
            :portshow_data=>'portWwn: 00:00:00:00:00:00:00:03
              portWwn of device(s) connected:

              Distance:  normal'.strip
          }

          @expected_interface_data << @profiler.network_interface_template.merge({
            :auto_negotiate=>true,
            :current_speed_mbps=>8000,
            :is_uplink=>true,
            :model=>'Unknown Fibre Adapter',
            :name=>'fc1/0',
            :port_wwn=>'00:00:00:00:00:00:00:01',
            :status=>'up',
            :type=>'fibre',
            :vendor=>VENDOR_BROCADE
          })

          @expected_interface_data << @profiler.network_interface_template.merge({
            :current_speed_mbps=>2000,
            :model=>'Unknown Fibre Adapter',
            :name=>'fc1/1',
            :port_wwn=>'00:00:00:00:00:00:00:02',
            :remote_wwn=>'00:00:00:00:00:00:01:00',
            :status=>'up',
            :type=>'fibre',
            :vendor=>VENDOR_BROCADE
          })

          @expected_interface_data << @profiler.network_interface_template.merge({
            :model=>'Unknown Fibre Adapter',
            :name=>'fc1/2',
            :port_wwn=>'00:00:00:00:00:00:00:03',
            :status=>'down',
            :type=>'fibre',
            :vendor=>VENDOR_BROCADE
          })
        end

        should 'return interface information via #get_network_interfaces' do
          @connector.stubs(:values_at).with(@ifmodeshow_command).returns(@ifmodeshow_data)
          @connector.stubs(:values_at).with(@ipaddr_command).returns(@ipaddr_data)
          @connector.stubs(:values_at).with(@switchshow_command).returns(@switchshow_data)

          @fibre_portshow_data.each do |fibre_port|
            @connector.stubs(:values_at).with("portshow #{fibre_port[:index]}").returns(fibre_port[:portshow_data].strip.split(/\n/))
          end

          @profiler.get_network_interfaces
          assert_equal(@expected_interface_data, @profiler.network_interfaces)
        end
      end

      context 'for operating system information' do
        setup do
          @expected_data = {
            :date_installed=>nil,
            :features=>[],
            :kernel=>'2.2.0.0',
            :license_key=>nil,
            :name=>'Brocade Fabric OS',
            :roles=>[],
            :service_pack=>nil,
            :version=>'5.0.0b'
          }
        end

        should 'return operating system information via #get_operating_system' do
          @connector.stubs(:values_at).with(@version_command).returns(@version_data)

          @profiler.get_operating_system
          assert_equal(@expected_data, @profiler.operating_system)
        end
      end
    end
  end
end