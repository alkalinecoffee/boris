module Boris
  class Options
    attr_accessor :options

    def initialize(options={})
      @options = {}

      # set our defaults
      @options[:auto_scrub_data] ||= true
      @options[:connection_types] ||= VALID_CONNECTION_TYPES
      @options[:credentials] ||= []
      @options[:log_level] ||= :fatal
      @options[:profiles] ||= [Profiles::RedHat, Profiles::Solaris]
      @options[:profiles] << [Profiles::Windows::Windows2003, Profiles::Windows::Windows2008, Profiles::Windows::Windows2012] if PLATFORM == :win32
      @options[:snmp_options] ||= {}
      @options[:ssh_options] ||= {}

      invalid_options = options.keys - @options.keys
      if invalid_options.any?
        raise ArgumentError, "invalid options specified (#{invalid_options.join(", ")})"
      end

      # override the defaults with passed in options
      @options.merge!(options)
    end

    def [](key)
      @options[key]
    end
    
    def []=(key, val)
      raise ArgumentError, 'invalid option provided' if !@options.has_key?(key)
      @options[key] = val
    end

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
  end
end