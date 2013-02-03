require 'boris/connectors/snmp'
require 'boris/connectors/ssh'
require 'boris/connectors/wmi'

require 'boris/profiles/linux/redhat'
require 'boris/profiles/unix/solaris'

require 'boris/profiles/windows/windows2003'
require 'boris/profiles/windows/windows2008'
require 'boris/profiles/windows/windows2012'

module Boris
  PORT_DEFAULTS = {:ssh=>22, :wmi=>135}
  VALID_CONNECTION_TYPES = [:snmp, :ssh, :wmi]

  # {Boris::Target} is the basic class from which you can control the underlying framework
  # for communicating with the device you wish to scan.  A Target will allow you to provide
  # options via {Boris::Options}, detect which profile to use, connect to, and eventually
  # scan your target device, returning a large amount of data.
  class Target
    include Lumberjack

    attr_reader :host
    attr_reader :target_profile
    attr_reader :unavailable_connection_types

    attr_accessor :connector
    attr_accessor :options
    attr_accessor :logger

    # Create the target by passing in a mandatory hostname or IP address, and optional
    # {Boris::Options options hash}.
    #
    # When a block is passed, the {Boris::Target} object itself is returned, and the connection
    # will be automatically disconnected at the end of the block (if it exists).
    #
    #  require 'boris'
    #
    #  target = Boris::Target.new('192.168.1.1', :log_level=>:debug)
    #
    # @param [String] host hostname or IP address
    # @param [Hash] options an optional list of options. See {Boris::Options} for a list of all
    #   possible options.
    def initialize(host, options={})
      @host = host

      options ||= {}
      @options = Options.new(options)

      @logger = BorisLogger.new(STDERR)

      if @options[:log_level]
        @logger.level = case @options[:log_level]
        when :debug then Logger::DEBUG
        when :info then Logger::INFO
        when :warn then Logger::WARN
        when :error then Logger::ERROR
        when :fatal then Logger::FATAL
        else raise ArgumentError, "invalid logger level specified (#{@options[:log_level].inspect})"
        end
      end

      @unavailable_connection_types = []

      if block_given?
        yield self
        disconnect if @connector && @connector.connected?
      else
        self
      end
    end

    # Connects to the target using the credentials supplied via the connection type as specified
    # by the credential.  This method will smartly bypass any further connection attempts if it
    # is determined that the connection will likely never work (for example, if you try to
    # connect via WMI to a Linux host (which will fail), any further attempts to connect to that
    # host via WMI will be ignored).
    # @raise [ConnectionAlreadyActive] when a connection is already active
    # @raise [InvalidOption] if credentials are not specified in the target's options hash
    # @return [Boolean] returns true if the connection attempt succeeded
    def connect
      if @connector && @connector.connected?
        raise ConnectionAlreadyActive, 'a connect attempt has been made when active connection already exists'
      elsif @options[:credentials].empty?
        raise InvalidOption, 'no credentials specified'
      end
      
      debug 'preparing to connect'

      @options[:credentials].each do |cred|
        if @connector && @connector.connected?
          debug 'active connection established, will not try any more credentials'
          break
        end

        debug "using credential (#{cred[:user]})"

        cred[:connection_types].each do |conn_type|
          if @connector && @connector.connected?
            debug 'active connection established, will not try any more connection types'
            break
          end

          case conn_type
          when :snmp
            @connector = SNMPConnector.new(@host, cred, @options, @logger)
            @connector.establish_connection
            # we won't add snmp to the @unavailable_connection_types array, as it
            # could respond later with another community string
          when :ssh
            if !@unavailable_connection_types.include?(:ssh)
              @connector = SSHConnector.new(@host, cred, @options, @logger)
              @connector.establish_connection

              if @connector.reconnectable == false
                @unavailable_connection_types << :ssh
              end
            end
          when :wmi
            if !@unavailable_connection_types.include?(:wmi)
              @connector = WMIConnector.new(@host, cred, @options, @logger)
              @connector.establish_connection
            
              if @connector.reconnectable == false
                @unavailable_connection_types << :wmi
              end
            end
          end

          info "connection established via #{conn_type}" if @connector.connected?
        end
      end

      @connector = nil if @connector.connected? == false

      return @connector ? true : false
    end

    # Checks on the status of the connection.
    #
    # @return [Boolean] returns true if the connection to the target is active
    def connected?
      @connector.connected
    end

    # Cycles through all of the profiles as specified in {Boris::Options} for this
    # target.  Each profile includes a method for determining whether the output of a
    # certain command will properly fit the target.  Once a suitable profile is
    # determined, it is then loaded up, which provides {Boris} the instructions on
    # how to proceed.
    #
    # @raise [InvalidOption] if no profiles are loaded prior to calling #detect_profile
    # @raise [NoActiveConnection] if no active connection is available when calling
    #  #detect_profile
    # @raise [NoProfileDetected] when no suitable profile was found
    # @return [Module] returns the Module of a suitable profile, else it will throw
    #  an error
    # @see #force_profile_to
    def detect_profile
      raise InvalidOption, 'no profiles loaded' if @options[:profiles].empty? || @options[:profiles].nil?
      raise NoActiveConnection, 'no active connection' if (!@connector || @connector.connected? == false)

      @target_profile = nil

      @options[:profiles].each do |profile|
        break if @target_profile

        if profile.connection_type == @connector.class
          debug "testing profile: #{profile}"

          if profile.matches_target?(@connector)
            @target_profile = profile

            debug "suitable profile found (#{@target_profile})"

            self.extend @target_profile
            
            debug "profile set to #{@target_profile}"
          end
        end
      end

      raise NoProfileDetected, 'no suitable profile found' if !@target_profile

      @target_profile
    end

    # Gracefully disconnects from the target (if a connection exists).
    #
    # @return [Boolean] returns true if the connection disconnected successfully
    def disconnect
      @connector.disconnect
      true if @connector.connected? == false
    end

    # Allows us to force the use of a profile.  This can be used instead of #detect_profile.
    # @param profile the module of the profile we wish to set the target to use
    # @see #detect_profile
    def force_profile_to(profile)
      self.extend profile
      @target_profile = profile
      debug "profile successfully forced to #{profile}"
    end

    # Calls all data-collecting methods. Probably will be used in most cases after a
    # connection has been established to the host.
    # @note Running the full gamut of data collection methods may take some time, and
    #  connections over WMI usually take longer than their SSH counterparts.  Typically,
    #  a Linux server scan can be completed in around a minute, where a Windows host
    #  will be completed in 2-3 minutes (in a perfect world, of course).
    # Methods that will be called include:
    # * get_file_systems (Array)
    # * get_hardware (Hash)
    # * get_hosted_shares (Array)
    # * get_installed_applications (Array)
    # * get_local_user_groups (Array)
    # * get_installed_patches (Array)
    # * get_installed_services (Array)
    # * get_network_id (Hash)
    # * get_network_interfaces (Array)
    # * get_operating_system (Hash)
    #
    #  target.retrieve_all
    #  target.file_systems.size #=> 2
    #  target.installed_applications.first #=> {:application_name=>'Adobe Reader'...}
    #
    # @see Boris::Profiles::Structure Profiles::Structure: a complete list of the data scructure
    # This method will also scrub the data after retrieving all of the items.
    def retrieve_all
      debug 'retrieving all configuration items'

      get_file_systems
      get_hardware
      get_hosted_shares
      get_installed_applications
      get_local_user_groups
      get_installed_patches
      get_installed_services
      get_network_id
      get_network_interfaces
      get_operating_system

      debug 'all items retrieved successfully'

      scrub_data! if @options[:auto_scrub_data]
    end

    # Attempts to suggest a connection method based on whether certain TCP ports
    # on the target are responding (135 for WMI, 22 for SSH by default).  Can be
    # used to speed up the process of determining whether we should try to
    # connect to our host using different methods, or bypass certain attempts
    # entirely.
    #
    #  target = Target.new('redhatserver01')
    #  target.suggested_connection_method #=> :ssh
    #
    # @return [Symbol] returns :wmi, :ssh, or nil
    # @see tcp_port_responding?
    def suggested_connection_method
      connection_method = nil
      
      debug 'detecting if wmi is available'
      connection_method = :wmi if tcp_port_responding?(PORT_DEFAULTS[:wmi])
      info 'wmi does not appear to be responding'

      if connection_method.nil?
        debug 'detecting if ssh is available'
        connection_method = :ssh if tcp_port_responding?(PORT_DEFAULTS[:ssh])
        info 'ssh does not appear to be responding'
      end

      info 'failed to detect connection method'if connection_method.nil?
      connection_method
    end

    # Checks if the supplied TCP port is responding on the target.  Useful for
    # determining which connection type we should use instead of taking more
    # time connecting to the target using different methods just to check if
    # they succeed or not.
    #
    #  target = Target.new('windowsserver01')
    #  target.tcp_port_responding?(22) #=> false
    #
    # @param port the TCP port number we wish to test
    # @return [Boolean] returns true of the supplied port is responding
    def tcp_port_responding?(port)
      status = false

      debug "checking if port #{port} is responding"

      begin
        conn = TCPSocket.new(@host, port)
        info "port #{port} is responding"
        conn.close
        debug "connection to port closed"
        status = true
      rescue
        info "port #{port} is not responding"
        status = false
      end

      status
    end

    # Parses the target's scanned data into JSON format for portability.
    #
    #  target.get_network_id
    #  json_string = target.to_json #=> "{\"domain\":\"mydomain.com\",\"hostname\":\"SERVER01\"}"...
    #  
    #  # The JSON string can later be parsed back into an object
    #  target_object = JSON.parse(json_string, :symbolize_names=>true)
    # @param pretty a boolean value to determine whether the data should be
    #  returned in json format with proper indentation.
    def to_json(pretty=false)
      json = {}

      data_vars = %w{
        file_systems
        hardware
        hosted_shares
        installed_applications
        installed_patches
        installed_services
        local_user_groups
        network_id
        network_interfaces
        operating_system
      }

      data_vars.each do |var|
          json[var.to_sym] = self.instance_variable_get("@#{var}".to_sym)
      end

      generated_json = pretty ? JSON.pretty_generate(json) : JSON.generate(json)

      debug "json generated successfully"

      generated_json
    end
  end
end
