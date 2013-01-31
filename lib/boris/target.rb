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

  class Target
    include Lumberjack

    attr_reader :host
    attr_reader :target_profile
    attr_reader :unavailable_connection_types

    attr_accessor :connector
    attr_accessor :options
    attr_accessor :logger

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

      yield self if block_given?
    end

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

    def connected?
      @connector.connected
    end

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

    def disconnect
      @connector.close
    end

    def force_profile_to(profile)
      self.extend profile
      @target_profile = profile
      debug "profile successfully forced to #{profile}"
    end

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

      info 'failed to detect connection method' if connection_method.nil?
      connection_method
    end

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

    # JSON.parse(json_string, :symbolize_names=>true)
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
