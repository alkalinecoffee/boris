require 'setup_tests'

class IOS12Test < BaseTestSetup
  context 'an IOS12 target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::IOS12)
      @target.force_profiler_to(Profilers::IOS12)
      @profiler = @target.profiler
      @connector.stubs(:values_at).with('show version | include (Version|ROM)').returns(['Cisco IOS, Version 12', 'ROM: 12.1'])
    end

    should 'detect when a target should use the CiscoIOS profile' do
      assert_equal(Profilers::IOS12, @profiler.class)
    end

    context 'being scanned' do
      setup do
      end

      context 'for operating system information' do
        setup do
          @show_version_command = 'show version | include (Version|ROM|uptime|CPU|bytes of memory)'
          @show_version_data = ['Cisco IOS Software, Version 12.1(1)SG1,']

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

