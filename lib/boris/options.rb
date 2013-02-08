require 'boris/profiler'

require 'boris/profilers/linux/redhat'
require 'boris/profilers/unix/solaris'
require 'boris/profilers/windows/windows2003'
require 'boris/profilers/windows/windows2008'
require 'boris/profilers/windows/windows2012'

module Boris
  class Options
    include Lumberjack

    attr_accessor :options

    # Creates our options hash where the user can pass in an optional hash to immediately
    # override the default values.
    #
    #  credentials = [{:user=>'joe', :password=>'mypassword', :connection_types=>[:ssh, :wmi]}]
    #  ssh_keys = ['/home/joe/private_key']
    #  options = Boris::Options.new(:log_level=>:debug, :ssh_options=>{:keys=>ssh_keys}, :credentials=>credentials)
    #
    # @option options [Boolean] :auto_scrub_data should the target's data be scrubbed
    #  after running #retrieve_all?
    # @option options [Array] :credentials an array of credentials in the format of
    #  +:user+, +:password+, +:connection_types+.  Only +:user+ is mandatory.
    # @option options [Symbol] :log_level a symbol for setting the log level
    #  # Options are: +:debug+, +:info+, +:warn+, +:error+, +:fatal+ (default)
    # @option options [Array] profilers An array of module names of the profiles we wish
    #  to have available for use on this target.  {Boris::Profilers::RedHat} and
    #  {Profilers::Solaris} are always the defaults, and Windows profilers are included
    #  as defaults as well if {Boris} is running on a Windows host (where WMI connections
    #  are available)
    # @option options [Hash] snmp_options A hash of options supported by ruby-snmp.
    # @option options [Hash] ssh_options A hash of options supported by net-ssh.
    #
    # @raise ArgumentError when invalid arguments are passed
    def initialize(options={})
      @options = {}

      # set our defaults
      @options[:auto_scrub_data] ||= true
      @options[:credentials] ||= []
      @options[:log_level] ||= :fatal
      @options[:profilers] ||= [Profilers::RedHat, Profilers::Solaris]
      @options[:profilers].concat([Profilers::Windows2003, Profilers::Windows2008, Profilers::Windows2012]) if PLATFORM == :win32
      @options[:snmp_options] ||= {}
      @options[:ssh_options] ||= {}

      invalid_options = options.keys - @options.keys
      if invalid_options.any?
        raise ArgumentError, "invalid options specified (#{invalid_options.join(", ")})"
      end

      # override the defaults with passed in Options
      @options.merge!(options)
    end

    # Getter method for grabbing a value from the Options.
    #  puts options[:profilers] #=> [Profilers::RedHat]
    #
    # @param key symbol of the key-value pair
    # @return returns the value of specified key from Options
    def [](key)
      @options[key]
    end

    # Setter method for setting the value in the options hash
    #  puts options[:profilers] #=> [Profilers::RedHat]
    #  options[:profilers] << Profilers::Solaris
    #  puts options[:profilers] #=> [Profilers::RedHat, Profilers::Solaris]
    # @raise ArgumentError when invalid options are provided
    def []=(key, val)
      raise ArgumentError, 'invalid option provided' if !@options.has_key?(key)
      @options[key] = val
    end

    # Provides a simple mechanism for adding credentials to the credentials array of Options.
    #
    # @param cred [Hash] a credential hash. Values include +:user+, +:password+, and
    #  +:connection_types+. +:user+ is mandatory, and +:connection_types+ should be an Array.
    # @raise ArgumentError when invalid credentials or connection_types are supplied
    def add_credential(cred)
      raise ArgumentError, 'invalid credential supplied (must be Hash)' if !cred.kind_of?(Hash)
      raise ArgumentError, 'username required' if !cred[:user]

      cred[:connection_types] ||= VALID_CONNECTION_TYPES

      invalid_options = cred[:connection_types] - VALID_CONNECTION_TYPES
      if invalid_options.any?
        raise ArgumentError, "invalid connection method specified (#{invalid_options.join(', ')})"
      end

      @options[:credentials] << cred unless @options[:credentials].include?(cred)
    end

    def set_log_level(level)
      @logger.level = case log_level
      when :debug then Logger::DEBUG
      when :info then Logger::INFO
      when :warn then Logger::WARN
      when :error then Logger::ERROR
      when :fatal then Logger::FATAL
      else raise ArgumentError, "invalid logger level specified (#{log_level.inspect})"
      end
    end
  end
end