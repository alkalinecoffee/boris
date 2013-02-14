require 'setup_tests'

class TargetTest < Test::Unit::TestCase
  context 'a Target' do
    setup do
      @host = '0.0.0.0'
      @target = Target.new(@host)
      @cred = {:user=>'someuser', :password=>'somepass'}
      @connector = @target.connector = SSHConnector.new(@host, @cred)      
    end

    should 'return host info after calling #load_host_info' do
      @target.expects(:load_host_info).returns([@host, nil])
      assert_equal(@target.load_host_info, [@host, nil])
    end

    should 'allow its target name to be readable' do
      assert_equal(@host, @target.host)
    end

    should 'allow its options to be modifiable by passing a block to Target#new' do
      Target.new(@host) do |t|
        t.options[:ssh_options] = {:timeout=>10}

        assert_equal({:timeout=>10}, t.options[:ssh_options])
      end
    end

    should 'allow its data (instance variables) to be produced as json' do
      @target.profiler = Profilers::Profiler.new(Connector.new(@host))
      long_json_string = %w{
        {"file_systems":null,
        "hardware":null,
        "hosted_shares":null,
        "installed_applications":null,
        "installed_patches":null,
        "installed_services":null,
        "local_user_groups":null,
        "network_id":null,
        "network_interfaces":null,
        "operating_system":null}}.join

      assert_equal(long_json_string, @target.to_json)
    end

    context 'listening on certain ports' do
      should "allow us to detect a possible SSH connection if it is listening on port #{PORT_DEFAULTS[:ssh]}" do
        Network.stubs(:tcp_port_responding?).with(@target.host, 22).returns(true)
        assert_equal(:ssh, Network.suggested_connection_method(@target.host))
      end

      should "allow us to detect a possible WMI connection if if it is listening on port #{PORT_DEFAULTS[:wmi]}" do
        Network.stubs(:tcp_port_responding?).with(@target.host, 22).returns(false)
        Network.stubs(:tcp_port_responding?).with(@target.host, 135).returns(true)
        assert_equal(:wmi, Network.suggested_connection_method(@target.host))
      end

      should 'return with no detected connection method if all attempts fail' do
        Network.stubs(:tcp_port_responding?).with(@target.host, 22).returns(false)
        Network.stubs(:tcp_port_responding?).with(@target.host, 135).returns(false)
        assert_nil(nil, Network.suggested_connection_method(@target.host))
      end
    end

    context 'that we will try to connect to' do
      setup do
        @connector.stubs(:connected?).returns(false)
      end

      should 'error if no credentials are specified' do
        assert_raise(InvalidOption) {@target.connect}
      end

      should 'error if we try to detect the profiler when there is no active connection' do
        assert_raise(NoActiveConnection) {@target.detect_profiler}
      end

      should 'attempt an SSH and WMI connection only once if the target does not respond to an attempt' do
        skip('test relies on WIN32OLE') if PLATFORM != :win32
        
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
        @target.stubs(:connect).returns(@connector)
        @connector.stubs(:connected?).returns(true)

        @target.options[:profilers].each do |profiler|
          profiler.stubs(:matches_target?).returns(false)
        end

        @target.connect
      end

      should 'allow us to call methods for retrieving all standard configuration items via #retrieve_all' do
        @target.profiler = Profilers::Profiler.new(@connector)
        @target.options[:auto_scrub_data] = false
        @target.retrieve_all

        assert_equal([], @target.profiler.file_systems)
        assert_equal([], @target.profiler.installed_applications)
        assert_equal([], @target.profiler.local_user_groups)
        assert_equal([], @target.profiler.network_interfaces)
        assert_equal([], @target.profiler.installed_patches)
        assert_equal([], @target.profiler.hosted_shares)
      end

      should 'raise an error if no profilers are found to be suitable' do
        assert_raise(NoProfilerDetected) {@target.detect_profiler}
      end

      should 'detect the best profiler for our target' do
        Profilers::RedHat.stubs(:matches_target?).returns(true)
        @connector.stubs(:class).returns(Boris::SSHConnector)
        assert_equal(Profilers::RedHat, @target.detect_profiler.class)
      end

      should 'allow us to force a profiler to be used for our target even if it is not ideal' do
        @target.force_profiler_to(Profilers::RedHat)
        assert_equal(Profilers::RedHat, @target.profiler.class)
      end
    end
  end
end
