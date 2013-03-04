require 'setup_tests'

class WMITest < Test::Unit::TestCase
  context 'a target listening for WMI connections' do
    setup do
      skip('test relies on WIN32OLE') if PLATFORM != :win32
      
      @target_name = '0.0.0.0'
      @cred = {:user=>'someuser', :password=>'somepass'}
      @connector = WMIConnector.new(@target_name, @cred)

      @win32ole = mock('WIN32OLE')

      WIN32OLE.stubs(:new).with('WbemScripting.SWbemLocator').returns(@win32ole)

      ['root\cimv2', 'root\WMI', 'root\default'].each do |namespace|
        @win32ole.stubs(:ConnectServer).with(@target_name, namespace, @cred[:user], @cred[:password], nil, nil, 128).returns(@win32ole)
      end
      @win32ole.stubs(:Get).with('StdRegProv').returns(@win32ole)
      
      @connector.establish_connection
    end

    context 'to which we cannot connect to' do
      should 'allow us to view the reason for failure' do
        WIN32OLE.stubs(:new).with('WbemScripting.SWbemLocator').raises(WIN32OLERuntimeError, 'access is denied')
        @connector.establish_connection
        assert_equal(@connector.failure_message, Boris::CONN_FAILURE_AUTH_FAILED)

        WIN32OLE.stubs(:new).with('WbemScripting.SWbemLocator').raises(WIN32OLERuntimeError, 'call was canceled by the message filter')
        @connector.establish_connection
        assert_equal(@connector.failure_message, Boris::CONN_FAILURE_RPC_FILTERED)

        WIN32OLE.stubs(:new).with('WbemScripting.SWbemLocator').raises(WIN32OLERuntimeError, 'rpc server is unavailable')
        @connector.establish_connection
        assert_equal(@connector.failure_message, Boris::CONN_FAILURE_RPC_UNAVAILABLE)

        WIN32OLE.stubs(:new).with('WbemScripting.SWbemLocator').raises(WIN32OLERuntimeError, 'some other error')
        @connector.establish_connection
        assert(@connector.failure_message =~ /^connection failed/)
      end
    end

    context 'to which we have already connected' do
      setup do
        @row = mock('row')
        
        @property = mock('property')

        @win32ole.stubs(:ExecQuery).returns([@row])
        @row.stubs(:Properties_).returns([@property])
      end

      should 'allow us to get property values with a wmi query from the cimv2 namespace via #execute' do
        @property.stubs(:Name).returns('Name')
        @property.stubs(:Value).returns('Windows Server 2008')
        assert_equal({:name=>'Windows Server 2008'}, @connector.value_at('SELECT Name FROM Win32_OperatingSystem'))
      end

      should 'allow us to get property values with a wmi query from the root wmi namespace via #execute' do
        @property.stubs(:Name).returns('InstanceName')
        @property.stubs(:Value).returns('VMware Accelerated AMD PCNet Adapter')
        assert_equal([:instancename=>'VMware Accelerated AMD PCNet Adapter'], @connector.values_at('SELECT * FROM MSNdis_HardwareStatus', :root_wmi))
      end

      should 'allow us to get attribute values from a wmi query via #execute' do
        attribute = mock('attribute')
        @row.stubs(:Attributes).returns(attribute)
        attribute.stubs(:Properties_).returns([@property])
        
        @property.stubs(:Name).returns('PortType')
        @property.stubs(:Value).returns(1)

        assert_equal([:porttype=>1], @connector.values_at('SELECT * FROM MSFC_FibrePortHBAAttributes', :root_wmi))
      end

      should 'error if an invalid limit for query is specified' do
        assert_raise(ArgumentError) {@connector.values_at('select * from something', nil, '5')}
      end
    end

    context 'to which we want to connect via the registry namespace' do
      setup do
        #@target.connect

        win32ole = mock('win32ole')

        @registry = @connector.registry = win32ole
        @registry.stubs(:Methods_).returns(win32ole)
        @registry.stubs(:inParameters).returns(win32ole)
        @registry.stubs(:SpawnInstance_).returns(win32ole)
        @registry.stubs(:ExecMethod_).returns(win32ole)
        @registry.stubs(:hDefKey=)
        @registry.stubs(:sSubKeyName=)

        @key_path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT'
      end

      should 'allow us to see if we have permissions to read certain registry keys via #has_access_for' do
        @registry.stubs(:uRequired=)
        @registry.stubs(:bGranted).returns(true)

        assert(@connector.has_access_for(@key_path))
      end

      context 'and read subkeys' do
        setup do
          @connector.stubs(:has_access_for).returns(true)
          @registry.stubs(:sNames).returns(['CurrentVersion'])
          @expected_data = ["#{@key_path}\\CurrentVersion"]
        end

        should 'allow us to access registry keys via #subkeys_at' do
          assert_equal(@expected_data, @connector.registry_subkeys_at(@key_path))
        end

        should 'cache already read registry subkeys' do
          @connector.stubs(:has_access_for).once.returns(true)

          assert_equal(@expected_data, @connector.registry_subkeys_at(@key_path))
          assert_equal([{:key_path=>@key_path, :subkeys=>@expected_data}], @connector.registry_cache)
          assert_equal(@expected_data, @connector.registry_subkeys_at(@key_path))
        end
      end

      context 'and read values' do
        setup do
          @key_path = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
          @connector.stubs(:has_access_for).returns(true)
          @registry.stubs(:sValueName=)
          @expected_data = {}
        end

        should 'return an empty hash from #registry_values_at when the path does not exist' do
          @registry.stubs(:sNames).returns([])

          @expected_data[:key_path] = 'HKEY_LOCAL_MACHINE\i\dont\exist'
          assert_equal({}, @connector.registry_values_at(@expected_data[:key_path]))
        end

        should 'allow us to access string values from the registry via #registry_values_at' do
          @registry.stubs(:sNames).returns(['ProductName'])
          @registry.stubs(:sValue).returns('Microsoft Windows Server 2008 R2')
          @registry.stubs(:uValue).returns(nil)

          @expected_data = {:productname=>'Microsoft Windows Server 2008 R2'}
          assert_equal(@expected_data, @connector.registry_values_at(@key_path))
        end

        should 'allow us to access other values from the registry via #registry_values_at' do
          @registry.stubs(:sNames).returns(['InstallDate'])
          @registry.stubs(:sValue).returns(nil)
          @registry.stubs(:uValue).returns(123456)

          @expected_data = {:installdate=>123456}
          assert_equal(@expected_data, @connector.registry_values_at(@key_path))
        end

        should 'cache already read registry values' do
          @connector.stubs(:has_access_for).once.returns(true)

          @registry.stubs(:sNames).returns(['ProductName'])
          @registry.stubs(:sValue).returns('Microsoft Windows Server 2008 R2')

          expected_data = {:productname=>'Microsoft Windows Server 2008 R2'}

          assert_equal(expected_data, @connector.registry_values_at(@key_path))
          assert_equal([{:key_path=>@key_path, :values=>expected_data}], @connector.registry_cache)
          assert_equal(expected_data, @connector.registry_values_at(@key_path))
        end
      end
    end
  end
end