require '..\setup_tests'

class Windows2008Test < ProfilerTestSetup
  context 'a Windows 2008 target' do
    setup do
      @connector = @target.connector = instance_of(WMIConnector)
      @target.stubs(:target_profiler).returns(Profilers::Windows2008)
      @target.force_profiler_to(Profilers::Windows2008)
      @connector.stubs(:value_at).with('SELECT Name FROM Win32_OperatingSystem').returns({:name=>'Windows Server 2008'})
    end

    # should 'detect when a target should use the Windows2008 profile' do
    #   assert_equal(Profilers::Windows2008, @target.profiler.class)
    # end

    context 'being scanned' do
      setup do
      end

      context 'for server features' do
        Profilers::Windows.instance_eval do
          def get_operating_system; nil; end
        end

        setup do
          @features_qry = 'SELECT Name FROM Win32_ServerFeature'
          @features_data = [{:name=>'File Server'}, {:name=>'Print Server'}]
          @connector.stubs(:values_at).with(@features_qry).returns(@features_data)

          @expected_data = @features_data.map{|h| h[:name]}
        end

        should 'return the enabled OS features of the OS' do
          @target.profiler.get_operating_system
          assert_equal(@expected_data, @target.profiler.operating_system)
        end
      end
    end
  end
end