require 'setup_tests'

module Profiles
  module Windows
    attr_accessor :operating_system
    def get_operating_system
      @operating_system = {:features=>[]}
    end
  end
end

class Windows2008Test < ProfileTestSetup
  extend Profiles::Structure
  include Profiles::Windows

  context 'a Windows 2008 target' do
    setup do
      @active_connection = @target.active_connection = instance_of(WMIConnector)

      @active_connection.stubs(:value_at).with('SELECT Name FROM Win32_OperatingSystem').returns({:name=>'Windows Server 2008'})
      @target.options[:profiles] = [Profiles::Windows2008]
      @target.detect_profile
    end

    context 'being scanned for OS information via #get_operating_system' do
      setup do
        @features_qry = 'SELECT Name FROM Win32_ServerFeature'
        @features_data = [{:name=>'File Server'},{:name=>'Print Server'}]
        @expected_data = @features_data.map{|h| h[:name]}
      end

      should 'return the enabled OS features of the OS (only provided by Windows 2008)' do
        @active_connection.stubs(:values_at).with(@features_qry).returns(@features_data)
        @target.get_operating_system
        assert_equal(@expected_data, @target.operating_system[:features])
      end
    end
  end
end
