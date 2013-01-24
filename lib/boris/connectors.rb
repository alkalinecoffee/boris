module Boris
  class Connector
    include Lumberjack

    attr_reader :connected
    attr_reader :host
    attr_reader :options
    attr_reader :reconnectable

    def initialize(host, cred, options, logger=nil)
      debug 'creating connection object'

      @host = host
      @user = cred[:user]
      @password = cred[:password]
      @connection_unavailable = false
      @connected = false

      @logger = logger
    end

    def connected?
      @connected
    end

    def establish_connection
      debug 'attempting connection'
    end

    def values_at(request, limit)
      raise ArgumentError, "invalid limit specified (#{limit})" if (!limit.nil? && limit < 1)

      amount = limit == 1 ? 'single value' : 'multiple values'

      debug "issuing request for #{amount} (#{request.inspect})"
    end

    def close
      debug 'closing connection to host'
      @connected = false
    end
  end
end
