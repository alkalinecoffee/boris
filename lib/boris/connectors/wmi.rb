require 'boris/connectors'

module Boris
  class WMIConnector < Connector
    attr_accessor :wmi, :root_wmi, :registry

    HKEY_LOCAL_MACHINE = 0x80000002
    KEY_QUERY_VALUE = 1
    KEY_ENUMERATE_SUB_KEYS = 8

    # Create an instance of WMIConnector by passing in a mandatory hostname or IP address,
    # credential to try, and optional Hash of {Boris::Options options}.  Under the hood, this
    # class uses the WIN32OLE library.
    #
    # @param [String] host hostname or IP address
    # @param [Hash] credential credential we wish to use
    # @param [Hash] options an optional list of options. See {Boris::Options} for a list of all
    #  possible options.
    def initialize(host, cred)
      super(host, cred)
    end

    # Disconnect from the host.
    def disconnect
      super
      @wmi = nil
      @registry = nil
      @root_wmi = nil

      debug 'connections closed'
    end
    
    # Establish our connection.  Three connection types are created: one to the WMI cimv2
    # namespace, one to the WMI root namespace, and one to the registry.
    # @return [WMIConnector] instance of WMIConnector
    def establish_connection
      super

      begin
        locator = WIN32OLE.new('WbemScripting.SWbemLocator')

        debug 'attempting connection to cimv2 namespace'
        @wmi = locator.ConnectServer(@host, 'root\cimv2', @user, @password, nil, nil, 128)
        debug 'connection to cimv2 namespace successful'
        
        debug 'attempting connection to wmi root namespace'
        @root_wmi = locator.ConnectServer(@host, 'root\WMI', @user, @password, nil, nil, 128)
        debug 'connection to wmi root namespace successful'

        debug 'attempting connection to registry'
        @registry = locator.ConnectServer(@host, 'root\default', @user, @password, nil, nil, 128).Get('StdRegProv')
        debug 'connection to registry successful'

        debug 'all required connections established'
        @connected = @reconnectable = true

      rescue WIN32OLERuntimeError => error
        @connected = false
        if error.message =~ /access is denied/i
          warn "connection failed (connection made but credentials not accepted with user #{@user})"
          @reconnectable = true
        elsif error.message =~ /rpc server is unavailable/i
          warn 'connection failed (rpc server not available)'
          @reconnectable = false
        else
          warn "connection failed (#{error.message.gsub(/\n\s*/, '. ')})"
          @reconnectable = true
        end
      end

      if @reconnectable == true
        info 'connection available for retry'
      elsif @reconnectable == false
        info 'connection does not seem to be available (so we will not retry)'
      end unless @transport

      self
    end

    # Return a single value from our request.
    #
    # @param [String] request the command we wish to execute over this connection
    # @param [Symbol] the channel we should use for our request
    #  Options: +:root_wmi+, +:wmi+ (default)
    # @return [String] the first row/line returned by the host
    def value_at(request, conn=:wmi)
      values_at(request, conn, limit=1)[0]
    end

    # Return multiple values from our request, up to the limit specified (or no
    # limit if no limit parameter is specified.
    #
    # @param [String] request the command we wish to execute over this connection
    # @param [Symbol] conn the channel we should use for our request
    #  Options: +:root_wmi+, +:wmi+ (default)
    # @param [Integer] limit the optional maximum number of results we wish to return
    # @return [Array] an array of rows returned by the query
    def values_at(request, conn=:wmi, limit=nil)
      super(request, limit)
      
      rows = case conn
      when :root_wmi
        @root_wmi.ExecQuery(request, nil, 48)
      when :wmi
        @wmi.ExecQuery(request, nil, 48)
      end

      return_data = []

      i = 0

      rows.each do |row|
        i += 1

        return_hash = {}

        row.Properties_.each do |property|
          if property.Name =~ /^attributes/i && property.Value.kind_of?(WIN32OLE)
            row.Attributes.Properties_.each do |property|
              return_hash[property.Name.downcase.to_sym] = property.Value
            end
          else
            return_hash[property.Name.downcase.to_sym] = property.Value
          end
        end

        return_data << return_hash

        break if (limit.nil? && i == limit)
      end

      debug "#{return_data.size} row(s) returned"

      return return_data
    end

    # Check if we have access to perform an action on the specified key path. This
    # adds a slight overhead in terms of registry read speed, as internally Boris
    # will check for access to enumerate subkeys for each registry key it wants to
    # read, but this does cut down on the number of access errors on the host.
    #
    #  # KEY_ENUMERATE_SUB_KEYS and KEY_QUERY_VALUE are constants specified in Boris.
    #  # Check Microsoft docs for other possible values.
    #  connector.has_access_for('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    #    KEY_ENUMERATE_SUB_KEYS) #=> true
    #
    # @param [String] key_path the registry key we wish to check access for
    # @param [Integer] permission_to_check the access we wish to test
    # @return [Boolean] true if we have access to perform this action on specified key
    def has_access_for(key_path, permission_to_check=nil)
      

      access_params = @registry.Methods_('CheckAccess').inParameters.SpawnInstance_

      access_params.hDefKey = HKEY_LOCAL_MACHINE
      access_params.sSubKeyName = key_path
      access_params.uRequired = permission_to_check

      @registry.ExecMethod_('CheckAccess', access_params).bGranted
    end

    # Returns an array of subkey names found at the specified key path under
    # HKEY_LOCAL_MACHINE.
    #
    #  connector.registry_subkeys_at('SOFTWARE\Microsoft')
    #   #=> ['SOFTWARE\Microsoft\Office', 'SOFTWARE\Microsoft\Windows'...]
    #
    # @param [String] key_path the registry key we wish to test
    # @return [Array] array of subkeys found
    def registry_subkeys_at(key_path)
      subkeys = []

      debug "reading registry subkeys at path #{key_path}"

      if has_access_for(key_path, KEY_ENUMERATE_SUB_KEYS)
        in_params = @registry.Methods_('EnumKey').inParameters.SpawnInstance_
        in_params.hDefKey = HKEY_LOCAL_MACHINE
        in_params.sSubKeyName = key_path

        @registry.ExecMethod_('EnumKey', in_params).sNames.each do |key|
          subkeys << key_path + '\\' + key
        end
      else
        info "no access for enumerating keys at (#{key_path})"
      end

      subkeys
    end

    # Returns an array of values found at the specified key path under
    # HKEY_LOCAL_MACHINE.
    #
    #  connector.registry_values_at('SOFTWARE\Microsoft')
    #   #=> {:valuename=>value, ...}
    #
    # @param [String] key_path the registry key we wish to test
    # @return [Hash] hash of key/value pairs found at the specified key path
    def registry_values_at(key_path)
      values = Hash.new

      debug "reading registry values at path #{key_path}"

      if has_access_for(key_path, KEY_QUERY_VALUE)
        in_params = @registry.Methods_('EnumValues').inParameters.SpawnInstance_
        in_params.hDefKey = HKEY_LOCAL_MACHINE
        in_params.sSubKeyName = key_path

        str_params = @registry.Methods_('GetStringValue').inParameters.SpawnInstance_
        str_params.sSubKeyName = key_path

        subkey_values = @registry.ExecMethod_('EnumValues', in_params).sNames
        subkey_values ||= []

        subkey_values.each do |value|
          if value.length > 0
            str_params.sValueName = value

            begin
              x = @registry.ExecMethod_('GetStringValue', str_params).sValue
              x = @registry.ExecMethod_('GetBinaryValue', str_params).uValue unless x
              x = @registry.ExecMethod_('GetDWORDValue', str_params).uValue unless x
              x = @registry.ExecMethod_('GetExpandedStringValue', str_params).sValue unless x
              x = @registry.ExecMethod_('GetMultiStringValue', str_params).sValue unless x
              x = @registry.ExecMethod_('GetQWORDValue', str_params).uValue unless x

              values[value.downcase.to_sym] = x
            rescue
              if $!.message =~ /invalid method/i
                warn "unreadable registry value (#{key_path}\\#{value})"
              end
            end
          end
        end
      else
        info "no access for enumerating values at (#{key_path})"
      end

      values
    end
  end
end