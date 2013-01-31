require 'setup_tests'

class TargetTest < Test::Unit::TestCase
  context 'a Target' do
    setup do
      @target = Target.new('0.0.0.0')
      @target.extend(Profiles::Structure)
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

    should 'allow us to call methods for retrieving all standard configuration items via #retrieve_all' do
      @target.options[:auto_scrub_data] = false
      @target.retrieve_all

      assert_equal([], @target.file_systems)
      assert_equal([], @target.installed_applications)
      assert_equal([], @target.local_user_groups)
      assert_equal([], @target.network_interfaces)
      assert_equal([], @target.installed_patches)
      assert_equal([], @target.hosted_shares)
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

      should 'attempt an SSH and WMI connection only once if the target does not respond to an attempt' do
        @target.options.add_credential(@cred.merge!(:connection_types=>[:snmp, :ssh, :wmi]))
        
        Net::SSH.stubs(:start).raises(Net::SSH::HostKeyMismatch)
        WIN32OLE.any_instance.stubs(:ConnectServer).raises(WIN32OLERuntimeError, 'rpc server is unavailable')

        SSHConnector.any_instance.expects(:establish_connection).once
        WMIConnector.any_instance.expects(:establish_connection).once

        @target.connect
      end

      should 'attempt a connection only once when connection is not available and when multiple credentials are supplied' do
        @target.options[:credentials] = [@cred.merge(:connection_types=>[:ssh])]
        @target.options[:credentials] << @cred.merge(:connection_types=>[:ssh])

        SSHConnector.any_instance.stubs(:reconnectable).returns(false)
        SSHConnector.any_instance.expects(:establish_connection).once

        @target.connect
      end
    end

    context 'that we have successfully connected to' do
      setup do
        ssh_connection = mock('SSHConnector')
        @target.connector = ssh_connection

        @target.connector.stubs(:connected?).returns(true)
        @target.connector.stubs(:class).returns(Connector::SSHConnector)
        @target.stubs(:connect).returns(@target.connector)

        @target.options[:profiles].each do |profile|
          profile.stubs(:matches_target?).returns(false)
        end

        @target.connect
      end

      should 'not find a profile if none are found to be suitable' do
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
