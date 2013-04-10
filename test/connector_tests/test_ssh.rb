require 'setup_tests'

class SSHTest < Test::Unit::TestCase
  context 'a target listening for SSH connections' do
    setup do
      @target_name = '0.0.0.0'
      @cred = {:user=>'someuser', :password=>'somepass'}
      @connector = SSHConnector.new(@target_name, @cred, Options.new)

      @transport = mock('SSHConnector')
      @transport.stubs(:exec!).with("\n").returns(nil)

      Net::SSH.stubs(:start).returns(@transport)

      @expected_data = 'SunOS'
    end

    should 'allow us to connect to it via SSH' do
      assert_kind_of(SSHConnector, @connector.establish_connection)
    end

    context 'to which we cannot connect to' do
      should 'allow us to view the reason for failure' do
        Net::SSH.stubs(:start).raises(Net::SSH::AuthenticationFailed)
        @connector.establish_connection
        assert_equal(@connector.failure_message, Boris::CONN_FAILURE_AUTH_FAILED)

        Net::SSH.stubs(:start).raises(Net::SSH::HostKeyMismatch)
        @connector.establish_connection
        assert_equal(@connector.failure_message, Boris::CONN_FAILURE_HOST_KEY_MISMATCH)

        Net::SSH.stubs(:start).raises(SocketError)
        @connector.establish_connection
        assert_equal(@connector.failure_message, Boris::CONN_FAILURE_NO_HOST)

        Net::SSH.stubs(:start).raises(SocketError, 'some other error')
        @connector.establish_connection
        assert(@connector.failure_message =~ /connection failed/i)

        Net::SSH.stubs(:start).returns(@transport)
        @transport.stubs(:exec!).with("\n").returns('password has expired')
        @connector.establish_connection
        assert_equal(@connector.failure_message, Boris::CONN_FAILURE_PASSWORD_EXPIRED)
      end
    end

    context 'to which we have already connected' do
      setup do
        @connector.establish_connection

        @channel = mock('channel')
        @transport.stubs(:open_channel).returns(@channel).then.yields(@channel)
        @channel.stubs(:on_data).yields(@channel, @expected_data)
        @channel.stubs(:on_extended_data).returns(@channel)
        @channel.stubs(:on_close).returns
        @channel.expects(:exec).at_least_once
        @channel.expects(:wait).at_least_once
      end

      should 'allow us to retrieve data' do
        assert_equal(@expected_data, @connector.value_at('uname'))
        assert_equal([@expected_data], @connector.values_at('uname'))
      end

      # should 'reconnect if a channel was closed prematurely' do
      #   @connector.expects(:establish_connection).once #more
      #   @channel.stubs(:on_close).yields(@channel)
      #   assert_equal(@expected_data, @connector.value_at('uname'))
      # end

      should 'request pty if needed' do
        @channel.expects(:request_pty).once
        assert_equal(@expected_data, @connector.value_at('uname', true))
      end
    end
  end
end