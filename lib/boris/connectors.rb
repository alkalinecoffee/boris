module Boris
  # The Connector class is the parent of the main Connector types that Boris
  # utilizes (WMI, SNMP, and SSH). It's primary purpose is to create the general
  # structure of a connector and offer some debugging messages for different
  # actions. Typically, Connector objects would not be created by user code.
  # Instead, your own connectors would be a subclass of Connector with calls
  # to super as appropriate.
  class Connector
    include Lumberjack

    attr_reader :connected
    attr_reader :host
    attr_reader :options
    attr_reader :reconnectable
    attr_reader :failure_messages
    attr_reader :user

    def initialize(host, cred={})
      @logger = Boris.logger
      
      @host = host
      @user = cred[:user]
      @password = cred[:password]
      @connected = false
      @failure_messages = []
      @reconnectable = true
      debug 'creating connection object'
    end

    # Convience method for retrieveing the connection status for this Connector.
    #
    #  connector.connected? #=> true
    #
    # @return [Boolean] true if connected
    def connected?
      @connected
    end

    # Disconnect from the host.
    def disconnect
      info 'closing connection to host'
      @connected = false
    end

    # Establish our connection.
    def establish_connection
      debug 'attempting connection'
    end

    # Only to be called from a child class, as this method only performs some simple
    # checks for errors and provides debugging messages.  Not intended to be directly
    # called from user code.
    #
    # @param [String] request the command we wish to execute over this connection
    # @param [Integer] limit the maximum number of results we wish to return
    def values_at(request, limit)
      if !limit.kind_of?(Integer)
        raise ArgumentError, "non-integer limit specified (#{limit.inspect})"
      elsif limit < 1
        raise ArgumentError, "specified limit must be greater than 1 (or nil for no limit) (#{limit.inspect})"
      end unless limit.nil?

      amount = limit == 1 ? 'single value' : 'multiple values'

      debug "issuing request for #{amount} (#{request.strip})"
    end
  end
end
