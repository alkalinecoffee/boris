require 'setup_tests'

class Windows2008Test < BaseTestSetup
  context 'a Windows 2008 target' do
    setup do
      @connector = @target.connector = WMIConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::Windows2008)
      @target.force_profiler_to(Profilers::Windows2008)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with('SELECT Name FROM Win32_OperatingSystem').returns({:name=>'Windows Server 2008'})
    end

    should 'detect when a target should use the Windows2008 profile' do
      assert_equal(Profilers::Windows2008, @profiler.class)
    end

    context 'being scanned' do
      setup do
      end

      context 'for operating system features' do
        setup do
          @features_qry = 'SELECT Name FROM Win32_ServerFeature'
          @features_data = [{:name=>'File Server'}, {:name=>'Print Server'}]
          @connector.stubs(:values_at).with(@features_qry).returns(@features_data)

          # we have to bypass the call to Windows#get_operating_system, so we manually
          # grab the core structure from Structure and call Windows2008's private
          # method (via instance_eval below).
          @profiler.operating_system = Class.new.extend(Structure).get_operating_system

          @expected_data = {:date_installed=>nil,
            :kernel=>nil,
            :license_key=>nil,
            :name=>nil,
            :service_pack=>nil,
            :version=>nil,
            :features=>@features_data.map{|h| h[:name]},
            :roles=>[]
          }
        end

        should 'return the enabled OS features of the OS' do
          @profiler.instance_eval {get_operating_system_features}
          assert_equal(@expected_data, @profiler.operating_system)
        end
      end
    end
  end
end