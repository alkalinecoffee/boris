require 'ostruct'
require 'setup_tests'

class SNMPTest < Test::Unit::TestCase
  context 'a target listening for SNMP requests' do
    setup do
      @target_name = '0.0.0.0'
      @cred = {:user=>'someuser', :password=>'somepass'}
      @active_connection = SNMPConnector.new(@target_name, @cred, Options.new)

      @transport = mock('SNMP')

      SNMP::Manager.stubs(:new).returns(@transport)

      @expected_value = {:name=>'sysDescr.0', :value=>'string'}

      @transport.stubs(:walk).with('sysDescr').yields([OpenStruct.new(@expected_value)])
    end

    should 'allow us to connect to it' do
      assert_kind_of(SNMPConnector, @active_connection.establish_connection)
    end

    context 'to which we have already connected' do
      setup do
        @active_connection.establish_connection
      end

      should 'allow us to perform a simple SNMP GET' do
        assert_equal(@expected_value, @active_connection.value_at('sysDescr'))
        assert_equal([@expected_value], @active_connection.values_at('sysDescr'))
      end
    end
  end
end