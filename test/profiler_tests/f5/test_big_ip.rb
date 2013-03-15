require 'setup_tests'

class BigIPCoreTest < ProfilerTestSetup
  context 'an F5 BIG-IP target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::BigIPCore)
      @target.force_profiler_to(Profilers::BigIPCore)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with('uname -a').returns('GNU/Linux')
    end


    should 'detect when a target should use the BigIPCore profile' do
      assert_equal(Profilers::BigIPCore, @profiler.class)
    end

    context 'being scanned' do
      setup do
      end

      context 'for file system information' do
        setup do
        end

        should 'return file system information via #get_file_systems' do
          #@profiler.get_file_systems
          #assert_equal(@expected_data, @profiler.file_systems)
        end
      end

      context 'for hardware information' do
        setup do
        end

        should 'return hardware information via #get_hardware' do
          # @profiler.get_hardware
          # assert_equal(@expected_data, @profiler.hardware)
        end
      end

      context 'for hosted shares' do
        setup do
        end

        should 'return hosted share information via #get_hosted_shares' do
          #@profiler.get_hosted_shares
          #assert_equal(@expected_data, @profiler.hosted_shares)
        end
      end

      context 'for installed applications' do
        setup do
        end

        should 'return installed applications via #get_installed_applications' do
          # @profiler.get_installed_applications
          # assert_equal([expected_data], @profiler.installed_applications)
        end
      end

      context 'for installed patches' do
        should 'return installed applications via #get_installed_patches' do
          # @profiler.get_installed_patches
          # assert_equal(expected_data, @profiler.installed_patches)
        end
      end

      context 'for installed services' do
        setup do
        end

        should 'return service information via #get_installed_services' do
          # @profiler.get_installed_services
          # assert_equal(@expected_data, @profiler.installed_services)
        end
      end


      context 'for local users and groups' do
        should 'return local user groups and accounts via #get_local_user_groups' do
          # @profiler.get_local_user_groups
          # assert_equal(expected_data, @profiler.local_user_groups)
        end

      end

      context 'for network identification' do
        setup do
          # @expected_data = {:domain=>'mydomain.com', :name=>'SERVER01'}
        end

        should 'return the domain and hostname via #get_network_id' do
          # @profiler.get_network_id
          # assert_equal(@profiler.network_id[:domain], @expected_data[:domain])
          # assert_equal(@profiler.network_id[:hostname], @expected_data[:name])
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

        end

        should 'return ethernet interface information via #get_network_interfaces' do
          # @profiler.get_network_interfaces
          # assert_equal(@expected_ethernet_data, @profiler.network_interfaces)
        end
      end

      context 'for operating system information' do
        setup do
          # @expected_data = {
          #   :date_installed=>DateTime.parse(@os_data[:installdate]),
          #   :features=>[],
          #   :kernel=>@os_data[:version],
          #   :license_key=>nil,
          #   :name=>'Microsoft Windows',
          #   :roles=>@os_data[:roles],
          #   :service_pack=>@os_data[:csdversion],
          #   :version=>'Server 2003 R2 Standard'
          # }
        end

        should 'return operating system information via #get_operating_system' do
          # @profiler.get_operating_system
          # assert_equal(@expected_data, @profiler.operating_system)
        end
      end
    end
  end
end