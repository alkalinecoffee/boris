require 'setup_tests'

class NXOS5Test < BaseTestSetup
  context 'an NXOS5 target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::NXOS5)
      @target.force_profiler_to(Profilers::NXOS5)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with("show version | grep -i 'system version'").returns('System version: 5')
    end

    should 'detect when a target should use the NXOS5 profile' do
      assert_equal(Profilers::NXOS5, @profiler.class)
    end

    context 'being scanned' do
      setup do
      end

      context 'for operating system information' do
        setup do
          @show_version_command = 'show version | grep -i "bios:\|system version\|chassis\|memory\|device"'
          @show_version_data = ['System version: 5.1(1)N1(1)']

          @expected_data = {
            :date_installed=>nil,
            :features=>[],
            :kernel=>'5.1(1)N1(1)',
            :license_key=>nil,
            :name=>'Cisco Nexus Operating System',
            :roles=>[],
            :service_pack=>nil,
            :version=>'5.1'
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
