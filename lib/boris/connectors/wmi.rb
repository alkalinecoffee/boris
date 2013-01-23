require 'boris/connectors'

module Boris
  class WMIConnector < Connector

    attr_accessor :wmi, :root_wmi, :registry

    HKEY_LOCAL_MACHINE = '&H80000002'
    KEY_QUERY_VALUE = 1
    KEY_ENUMERATE_SUB_KEYS = 8

    def initialize(host, cred, options, logger=nil)
      super(host, cred, options, logger)
    end

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
      rescue WIN32OLERuntimeError => error
        if error.message =~ /access is denied/i
          warn "connection failed (connection made but credentials not accepted with user #{@user})"
        else
          warn "connection failed (#{error.message})"
          raise error
        end
      end

      return self
    end

    def close
      super
      @wmi = nil
      @registry = nil
      @root_wmi = nil

      debug 'connections closed'
    end

    def value_at(request, conn=:wmi)
      values_at(request, conn)[0]
    end

    def values_at(request, conn=:wmi)
      super(request)
      
      rows = case conn
      when :root_wmi
        @root_wmi.ExecQuery(request, nil, 48)
      when :wmi
        @wmi.ExecQuery(request, nil, 48)
      end

      return_data = []

      rows.each do |row|
        row.Properties_.each do |property|
          if property.Name =~ /^attributes/i && property.Value.kind_of?(WIN32OLE)
            row.Attributes.Properties_.each do |property|
              return_data << {property.Name.downcase.to_sym => property.Value}
            end
          else
            return_data << {property.Name.downcase.to_sym => property.Value}
          end
        end
      end

      info "#{return_data.size} values returned"

      return return_data
    end

    def has_access_for(key_path, permission_to_check=nil)
      debug "checking for registry read access for #{key_path}"

      access_params = @registry.Methods_('CheckAccess').inParameters.SpawnInstance_

      access_params.hDefKey = 9
      access_params.sSubKeyName = key_path
      access_params.uRequired = permission_to_check

      @registry.ExecMethod_('CheckAccess', access_params).bGranted
    end

    def registry_subkeys_at(key_path)
      return_data = []

      debug "reading registry subkeys at path #{key_path}"

      if has_access_for(key_path, KEY_ENUMERATE_SUB_KEYS)
        in_params = @registry.Methods_('EnumKey').inParameters.SpawnInstance_
        in_params.hDefKey = HKEY_LOCAL_MACHINE
        in_params.sSubKeyName = key_path

        @registry.ExecMethod_('EnumKey', in_params).sNames.each do |key|
          return_data << key_path + '\\' + key
        end
      else
        info "no access for enumerating keys at (#{key_path})"
      end

      return return_data
    end

    def registry_values_at(key_path)
      values = Hash.new

      debug "reading registry values at path #{key_path}"

      if has_access_for(key_path, KEY_QUERY_VALUE)
        in_params = @registry.Methods_('EnumValues').inParameters.SpawnInstance_
        in_params.hDefKey = HKEY_LOCAL_MACHINE
        in_params.sSubKeyName = key_path

        str_params = @registry.Methods_('GetStringValue').inParameters.SpawnInstance_
        str_params.sSubKeyName = key_path

        @registry.ExecMethod_('EnumValues', in_params).sNames.each do |value|
          if !value.empty?
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
              if $!.message =~ /#{invalid method}/i
                warn "unreadable registry value (#{key_path}\\#{value})"
              end
            end
          end
        end
      else
        info "no access for enumerating values at (#{key_path})"
      end

      return values
    end
  end
end