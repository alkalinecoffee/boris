require 'boris/errors'
require 'boris/options'
require 'boris/connectors/snmp'
require 'boris/connectors/ssh'
require 'boris/connectors/wmi'

module Boris
  # {Boris::Target} is the basic class from which you can control the underlying framework
  # for communicating with the device you wish to scan.  A Target will allow you to provide
  # options via {Boris::Options}, detect which profiler to use, connect to, and eventually
  # scan your target device, returning a large amount of data.
  class Target
    include Lumberjack
    
    attr_reader :host
    attr_reader :unavailable_connection_types

    attr_accessor :connector
    attr_accessor :profiler
    attr_accessor :options

    # Create the target by passing in a mandatory hostname or IP address, and optional
    # {Boris::Options options hash}.
    #
    # When a block is passed, the {Boris::Target} object itself is returned, and the connection
    # will be automatically disconnected at the end of the block (if it exists).
    #
    #  require 'boris'
    #
    #  target = Boris::Target.new('192.168.1.1', :auto_scrub_data=>false)
    #
    # @param [String] host hostname or IP address
    # @param [Hash] options an optional list of options. See {Boris::Options} for a list of all
    #   possible options.
    def initialize(host, options={})
      @logger = Boris.logger

      @host = host

      options ||= {}
      @options = Options.new(options)
      @connector = Connector.new(@host)
      @unavailable_connection_types = []

      if block_given?
        yield self
        disconnect if @connector.connected?
      end
    end

    # Convience method for returning data already collected (internally looks at the Profiler
    # object of Target).
    #
    #  target.get(:hardware)
    #
    #  target[:hardware]          #=> {:cpu_architecture=>64, :cpu_core_count=>2...}
    #
    #  # same thing as:
    #
    #  target.profiler.hardware   #=> {:cpu_architecture=>64, :cpu_core_count=>2...}
    #
    # @param [Hash] category name
    # @return [Array, Hash] scanned data elements for provided category
    def [](category)
      @profiler.instance_variable_get("@#{category}".to_sym)
    end

    # Connects to the target using the credentials supplied via the connection type as specified
    # by the credential.  This method will smartly bypass any further connection attempts if it
    # is determined that the connection will likely never work (for example, if you try to
    # connect via WMI to a Linux host (which will fail), any further attempts to connect to that
    # host via WMI will be ignored).
    #
    # @raise [ConnectionAlreadyActive] when a connection is already active
    # @raise [InvalidOption] if credentials are not specified in the target's options hash
    # @return [Boolean] returns true if the connection attempt succeeded
    def connect
      if @connector.connected?
        raise ConnectionAlreadyActive, 'a connect attempt has been made when active connection already exists'
      elsif @options[:credentials].empty?
        raise InvalidOption, 'no credentials specified'
      end
      
      debug 'preparing to connect'

      @options[:credentials].each do |cred|
        if @connector.connected?
          debug 'active connection established, will not try any more credentials'
          break
        end

        debug "using credential (#{cred[:user]})"

        cred[:connection_types].each do |conn_type|
          if @connector.connected?
            debug 'active connection established, will not try any more connection types'
            break
          end

          case conn_type
          when :snmp
            @connector = SNMPConnector.new(@host, cred, @options)
            @connector.establish_connection
            # we won't add snmp to the @unavailable_connection_types array, as it
            # could respond later with another community string
          when :ssh
            if @unavailable_connection_types.include?(:ssh)
              debug 'connection attempt bypassed (ssh connection unavailable)'
            else
              @connector = SSHConnector.new(@host, cred, @options)
              @connector.establish_connection

              if @connector.reconnectable == false
                @unavailable_connection_types << :ssh
              end
            end
          when :wmi
            if @unavailable_connection_types.include?(:wmi)
              debug 'connection attempt bypassed (wmi connection unavailable)'
            else
              @connector = WMIConnector.new(@host, cred)
              @connector.establish_connection
            
              if @connector.reconnectable == false
                @unavailable_connection_types << :wmi
              end
            end
          end

          info "connection established via #{conn_type}" if @connector.connected?
        end
      end

      info 'all connection attempts failed' if !@connector.connected?

      return @connector.connected? ? true : false
    end

    # Checks on the status of the connection.
    #
    # @return [Boolean] returns true if the connection to the target is active
    def connected?
      @connector.connected?
    end

    # Cycles through all of the profilers as specified in {Boris::Options} for this
    # target. Each profiler includes a method for determining whether the output of a
    # certain command will properly fit the target.  Once a suitable profiler is
    # determined, it is then loaded up, which provides {Boris} the instructions on
    # how to proceed.
    #
    # @raise [InvalidOption] if no profilers are loaded prior to calling #detect_profiler
    # @raise [NoActiveConnection] if no active connection is available when calling
    #  #detect_profiler
    # @raise [NoProfilerDetected] when no suitable profiler was found
    # @return [Module] returns the Class of a suitable profiler, else it will throw
    #  an error
    # @see #force_profiler_to
    def detect_profiler
      raise InvalidOption, 'no profilers loaded' if @options[:profilers].empty? || @options[:profilers].nil?
      raise NoActiveConnection, 'no active connection' if @connector.connected? == false

      @options[:profilers].each do |profiler|
        break if @profiler || @connector.failure_message

        if profiler.connection_type == @connector.class
          debug "testing profiler: #{profiler}"

          if profiler.matches_target?(@connector)
            @profiler = profiler

            debug "suitable profiler found (#{profiler})"

            @profiler = @profiler.new(@connector)
            
            debug "profiler set to #{profiler}"
          end
        end
      end

      raise PasswordExpired,  @connector.failure_message if @connector.failure_message

      raise NoProfilerDetected, 'no suitable profiler found' if !@profiler

      @profiler
    end

    # Gracefully disconnects from the target (if a connection exists).
    #
    # @return [Boolean] returns true if the connection disconnected successfully
    def disconnect
      @connector.disconnect if @connector.connected?
    end

    # Allows us to force the use of a profiler.  This can be used instead of #detect_profiler.
    # @param profiler the module of the profiler we wish to set the target to use
    # @see #detect_profiler
    def force_profiler_to(profiler)
      @profiler = profiler.new(@connector)
      debug "profiler successfully forced to #{profiler}"
    end

    # Convience method for collecting data from a Target, where the user can pass in a symbol
    # for the category that should be collected.
    #
    #  target.get(:hardware)          #=> {:cpu_architecture=>64, :cpu_core_count=>2...}
    #
    #  # same thing as:
    #
    #  target.profiler.get_hardware   #=> {:cpu_architecture=>64, :cpu_core_count=>2...}
    #
    # @param [Hash] category name
    # @return [Array, Hash] scanned data elements for provided category
    def get(category)
      @profiler.send("get_#{category.to_s}")
      self[category]
    end

    # Calls all data-collecting methods. Probably will be used in most cases after a
    # connection has been established to the host.
    # @note Running the full gamut of data collection methods may take some time, and
    #  connections over WMI usually take longer than their SSH counterparts.  Typically,
    #  a Linux server scan can be completed in just a minute or two, whereas a Windows
    #  host will be completed in 2-3 minutes (there are many other factors, of course).
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
    #  target[:file_systems].size #=> 2
    #  target[:installed_applications].first #=> {:application_name=>'Adobe Reader'...}
    #
    # @see Boris::Profilers::Structure Profilers::Structure a complete list of the data scructure
    # This method will also scrub the data after retrieving all of the items (unless the
    #   :auto_scrub option is set to false).
    def retrieve_all
      raise NoActiveConnection, 'no active connection' if @connector.connected? == false

      debug 'retrieving all configuration items'

      Structure::CATEGORIES.each do |category|
        debug "calling #get_#{category.to_s}"
        @profiler.send("get_#{category.to_s}")
      end
      
      debug 'all items retrieved successfully'

      @profiler.scrub_data! if @options[:auto_scrub_data]
    end

    # Parses the target's scanned data into JSON format for portability.
    #
    #  target.get(:network_id)
    #  json_string = target.to_json #=> "...{\"domain\":\"mydomain.com\",\"hostname\":\"SERVER01\"}"...
    #
    # @param [Hash] print_type a symbol value for json output options.  Only option supported now
    #   is :pretty_print to determine whether the data should be returned in json format with
    #   proper indentation.
    # @return [JSON] a JSON object containing retrieved data from the target
    def to_json(print_type=:standard)
      json = {}

      Structure::CATEGORIES.each do |category|
        json[category.to_sym] = @profiler.instance_variable_get("@#{category}".to_sym)
      end

      generated_json = print_type == :pretty_print ? JSON.pretty_generate(json) : JSON.generate(json)

      debug "json generated successfully"

      generated_json
    end
  end
end
