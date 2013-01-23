require 'setup_tests'

class SSHTest < Test::Unit::TestCase
  context 'a target listening for SSH connections' do
    setup do
      @target_name = '0.0.0.0'
      @cred = {:user=>'someuser', :password=>'somepass'}
      @active_connection = SSHConnector.new(@target_name, @cred, Options.new)

      @transport = mock('SSHConnector')

      Net::SSH.stubs(:start).returns(@transport)

      @expected_data = 'SunOS'
    end

    should 'allow us to connect to it via SSH' do
      assert_kind_of(SSHConnector, @active_connection.establish_connection)
    end

    context 'to which we have already connected' do
      setup do
        @active_connection.establish_connection

        @channel = mock('channel')
        @transport.stubs(:open_channel).returns(@channel).then.yields(@channel)
        @channel.stubs(:on_data).yields(@channel, @expected_data)
        @channel.stubs(:on_extended_data).returns(@channel)
        @channel.stubs(:on_close).returns
        @channel.expects(:exec).at_least_once
        @channel.expects(:wait).at_least_once
      end

      should 'allow us to retrieve data' do
        assert_equal(@expected_data, @active_connection.value_at('uname'))
        assert_equal([@expected_data], @active_connection.values_at('uname'))
      end

      should 'reconnect if a channel was closed prematurely' do
        @active_connection.expects(:establish_connection).once #more
        @channel.stubs(:on_close).yields(@channel)
        assert_equal(@expected_data, @active_connection.value_at('uname'))
      end

      should 'request pty if needed' do
        @channel.expects(:request_pty).once
        assert_equal(@expected_data, @active_connection.value_at('uname', true))
      end
    end
  end
end