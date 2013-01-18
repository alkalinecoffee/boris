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

    attr_accessor :active_connection
    attr_accessor :options
    attr_accessor :logger

    def initialize(host, options={})
      @host = host

      @options = Options.new(options)

      self.logger = MiniLog.new(STDERR)
      self.logger.host = host

      if @options[:log_level]
        self.logger.level = case @options[:log_level]
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
      raise InvalidOption, 'no credentials specified' if @options[:credentials].empty?
      raise ConnectionAlreadyActive, 'a connect attempt has been made when active connection already exists' if @active_connection

      debug 'preparing to connect'

      creds_to_try = @options[:credentials].reject {|cred| (cred[:connection_types] && @options[:connection_types]).empty?}

      @active_connection = nil

      creds_to_try.each do |cred|
        break if @active_connection

        cred[:connection_types].each do |conn_type|
          break if @active_connection
          
          case conn_type
          when :snmp
            @active_connection = SNMPConnector.new(@host, cred, @options, logger).establish_connection
            warn 'snmp not available' if !@active_connection
            # we won't add snmp to the @unavailable_connection_types array, as it
            # could respond later with another community string
          when :ssh
            begin
              @active_connection = SSHConnector.new(@host, cred, @options, logger).establish_connection
            rescue
              warn 'ssh not available'
              @unavailable_connection_types << :ssh
            end unless @unavailable_connection_types.include?(:ssh)
          when :wmi
            begin
              @active_connection = WMIConnector.new(@host, cred, @options, logger).establish_connection
            rescue
              warn 'wmi not available'
              @unavailable_connection_types << :wmi
            end unless @unavailable_connection_types.include?(:wmi)
          end

          debug "connection established via #{conn_type}" if @active_connection
        end
      end

      @active_connection
    end

    def detect_profile
      raise InvalidOption, 'no profiles loaded' if @options[:profiles].empty? || @options[:profiles].nil?
      raise NoActiveConnection, 'no active connection' if !@active_connection

      @target_profile = nil
      @options[:profiles].each do |profile|
        if profile.matches_target?(@active_connection)
          debug "suitable profile found (#{profile})"
          @target_profile = profile
        end
      end

      if @target_profile
        self.extend @target_profile
        debug 'profile prepared successfully'
      end

      @target_profile
    end

    def disconnect
      @active_connection.close
    end

    def force_profile_to(profile)
      self.extend profile
      debug "profile successfully forced to #{profile}"
      @target_profile = profile
    end

    def suggested_connection_method
      connection_method = nil
      
      debug 'detecting if wmi is available'
      connection_method = :wmi if tcp_port_responding?(PORT_DEFAULTS[:wmi])
      warn 'wmi does not appear to be responding'

      if !connection_method
        debug 'detecting if ssh is available'
        connection_method = :ssh if tcp_port_responding?(PORT_DEFAULTS[:ssh])
        warn 'ssh does not appear to be responding'
      end

      warn 'failed to detect connection method' if !connection_method
      connection_method
    end

    def tcp_port_responding?(port)
      status = false

      debug "checking if port #{port} is responding"

      begin
        conn = TCPSocket.new(@host, port)
        debug "port #{port} is responding"
        true
      rescue
        debug "port #{port} is not responding"
        false
      ensure
        conn.close
      end

      status
    end

    def to_json
      vars_to_omit = [:@logger, :@options, :@unavailable_connection_types]
      
      json = {}

      (self.instance_variables - vars_to_omit).each do |var|
          json[var.to_s.delete('@')] = self.instance_variable_get(var)
      end

      JSON.generate(json)
      # JSON.parse(json_string, :symbolize_names=>true)
    end
  end
end
