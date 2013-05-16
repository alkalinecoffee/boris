require 'setup_tests'

class SSHTest < Test::Unit::TestCase
  context 'a target listening for SSH connections' do
    setup do
      @target_name = '0.0.0.0'
      @cred = {:user=>'someuser', :password=>'somepass'}
      @connector = SSHConnector.new(@target_name, @cred, Options.new)

      @transport = mock('SSHConnector')
      Net::SSH.stubs(:start).returns(@transport)

      @expected_data = 'SunOS'
    end

    should 'allow us to connect to it via SSH' do
      @transport.stubs(:open_channel)
      assert_kind_of(SSHConnector, @connector.establish_connection)
    end

    context 'to which we cannot connect to' do
      should 'allow us to view the reason for failure' do
        Net::SSH.stubs(:start).raises(Net::SSH::AuthenticationFailed)
        @connector.establish_connection
        assert_equal(@connector.failure_messages[0], Boris::CONN_FAILURE_AUTH_FAILED)

        Net::SSH.stubs(:start).raises(Net::SSH::HostKeyMismatch)
        @connector.establish_connection
        assert_equal(@connector.failure_messages[1], Boris::CONN_FAILURE_HOST_KEY_MISMATCH)

        Net::SSH.stubs(:start).raises(SocketError)
        @connector.establish_connection
        assert_equal(@connector.failure_messages[2], Boris::CONN_FAILURE_NO_HOST)

        Net::SSH.stubs(:start).raises(SocketError, 'some other error')
        @connector.establish_connection
        assert(@connector.failure_messages[3] =~ /connection failed/i)

        Net::SSH.stubs(:start).returns(@transport)
        @connector.stubs(:value_at).with("\n").returns('password has expired')
        @connector.establish_connection
        assert_equal(@connector.failure_messages[4], Boris::CONN_FAILURE_PASSWORD_EXPIRED)
      end
    end

    context 'to which we have already connected' do
      setup do
        @channel = mock('Channel')
        @transport.stubs(:open_channel).returns(@channel).yields(@channel)
        @channel.stubs(:exec).yields(@channel, true)
        @channel.stubs(:on_data).yields(@channel, @expected_data)
        @channel.stubs(:on_extended_data).returns(@channel)
        @channel.stubs(:on_close).returns
        
        @channel.expects(:wait).at_least_once

        @connector.establish_connection
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