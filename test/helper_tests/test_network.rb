require 'setup_tests'

class NetworkTest < Test::Unit::TestCase
  context 'the Network module' do
    setup do
      @host = '0.0.0.0'
    end
  
    should "allow us to detect a possible SSH connection if a host is listening on port #{PORT_DEFAULTS[:ssh]}" do
      Network.stubs(:tcp_port_responding?).with(@host, 22).returns(true)
      assert_equal(:ssh, Network.suggested_connection_method(@host))
    end

    should "allow us to detect a possible WMI connection if a host is listening on port #{PORT_DEFAULTS[:wmi]}" do
      Network.stubs(:tcp_port_responding?).with(@host, 22).returns(false)
      Network.stubs(:tcp_port_responding?).with(@host, 135).returns(true)
      assert_equal(:wmi, Network.suggested_connection_method(@host))
    end

    should 'return with no detected connection method if all attempts fail' do
      Network.stubs(:tcp_port_responding?).with(@host, 22).returns(false)
      Network.stubs(:tcp_port_responding?).with(@host, 135).returns(false)
      assert_nil(nil, Network.suggested_connection_method(@host))
    end
  end
end