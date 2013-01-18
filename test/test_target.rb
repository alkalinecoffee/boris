require 'setup_tests'

class TargetTest < Test::Unit::TestCase
  context 'a Target' do
    setup do
      @target = Target.new('0.0.0.0')
      @cred = {:user=>'someuser', :password=>'somepass'}
    end

    should 'return host info after calling #load_host_info' do
      @target.expects(:load_host_info).returns([@host, nil])
      assert_equal(@target.load_host_info, [@host, nil])
    end

    should 'allow its target name to be readable' do
      assert_equal('0.0.0.0', @target.host)
    end

    should 'allow its options to be modifiable by passing a block to Target#new' do
      Target.new(@host) do |t|
        t.options[:ssh_options] = {:timeout=>10}

        assert_equal({:timeout=>10}, t.options[:ssh_options])
      end
    end

    should 'allow its data (instance variables) to be produced as json' do
      assert_equal('{"host":"0.0.0.0"}', @target.to_json)
    end

    should 'allow credentials to be added through #add_credential' do
      @target.options.add_credential(@cred.merge!(:connection_types=>[:wmi]))
      assert_equal([@cred], @target.options[:credentials])
    end

    context 'listening on certain ports' do
      should "allow us to detect a possible SSH connection if it is listening on port #{Boris::PORT_DEFAULTS[:ssh]}" do
        @target.expects(:tcp_port_responding?).with(22).returns(true)
        @target.expects(:tcp_port_responding?).with(135).returns(false)
        assert_equal(:ssh, @target.suggested_connection_method)
      end

      should "allow us to detect a possible WMI connection if if it is listening on port #{Boris::PORT_DEFAULTS[:wmi]}" do
        @target.expects(:tcp_port_responding?).with(135).returns(true)
        assert_equal(:wmi, @target.suggested_connection_method)
      end

      should 'return with no detected connection method if all attempts fail' do
        @target.expects(:tcp_port_responding?).with(22).returns(false)
        @target.expects(:tcp_port_responding?).with(135).returns(false)
        assert_nil(nil, @target.suggested_connection_method)
      end
    end

    context 'that we will try to connect to' do
      should 'error if no credentials are specified' do
        assert_raise(InvalidOption) {@target.connect}
      end

      should 'error if we try to detect the profile when there is no active connection' do
        assert_raise(NoActiveConnection) {@target.detect_profile}
      end

      should 'attempt each connection type only once if the target does not respond to an attempt' do
        @target.options.add_credential(@cred.merge!(:connection_types=>[:snmp, :ssh, :wmi]))

        SNMPConnector.any_instance.expects(:establish_connection).at_most_once.returns(nil)
        SSHConnector.any_instance.expects(:establish_connection).at_most_once.raises(ConnectionFailed)
        WMIConnector.any_instance.expects(:establish_connection).at_most_once.raises(ConnectionFailed)

        @target.connect
      end

      should 'attempt a connection type only once even when multiple credentials for the same connection type are supplied' do
        @target.options[:credentials] = [@cred.merge(:connection_types=>[:ssh])]
        @target.options[:credentials] << @cred.merge(:connection_types=>[:ssh])

        SSHConnector.any_instance.expects(:establish_connection).at_most_once.raises(NoMethodError)

        @target.connect
      end

      should 'allow us to connect via SNMP' do
        input = 'sysDescr.0'
        output = 'some returned string'
        
        @target.options[:credentials] = [@cred.merge(:connection_types=>[:snmp])]

        connection = mock('SNMPConnector')
        SNMPConnector.any_instance.stubs(:establish_connection).returns(connection)
        @target.connect
        @target.active_connection.stubs(:execute).with(input).returns(output)

        assert_equal(output, @target.active_connection.execute(input))
      end

      should 'allow us to connect via SSH' do
        input = 'uname -a'
        output = 'some returned string'

        @target.options[:credentials] = [@cred.merge(:connection_types=>[:ssh])]

        connection = mock('SSHConnector')
        SSHConnector.any_instance.stubs(:establish_connection).returns(connection)
        @target.connect
        @target.active_connection.stubs(:execute).with(input).returns(output)

        assert_equal(output, @target.active_connection.execute(input))
       end

      should 'allow us to connect via WMI' do
        input = 'SELECT * FROM Win32_OperatingSystem'
        output = [:manufacturer=>'Microsoft Corporation']

        @target.options[:credentials] = [@cred.merge(:connection_types=>[:wmi])]

        connection = mock('WMIConnector')
        WMIConnector.any_instance.stubs(:establish_connection).returns(connection)
        @target.connect
        @target.active_connection.stubs(:execute).with(input).returns(output)

        assert_equal(output, @target.active_connection.execute(input))
      end
    end

    context 'that we have successfully connected to' do
      setup do
        ssh_connection = mock('SSHConnector')
        @target.stubs(:connect).returns(ssh_connection)
        @target.active_connection = ssh_connection

        @target.options[:profiles].each do |profile|
          profile.stubs(:matches_target?).returns(false)
        end

        @target.connect
      end

      should 'not find a profile if none are found to be suitable' do
        Profiles::RedHat.stubs(:matches_target?).returns(false)
        assert_nil(@target.detect_profile)
      end

      should 'detect the best profile for our target' do
        Profiles::RedHat.stubs(:matches_target?).returns(true)
        assert_equal(Profiles::RedHat, @target.detect_profile)
      end

      should 'allow us to force a profile to be used for our target even if it is not ideal' do
        assert_nil(@target.detect_profile)
        @target.force_profile_to(Profiles::RedHat)
        assert_equal(Profiles::RedHat, @target.target_profile)
      end
    end
  end
end
