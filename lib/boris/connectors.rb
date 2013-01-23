module Boris
  class Connector
    include Lumberjack

    attr_reader :options
    attr_reader :host

    def initialize(host, cred, options, logger=nil)
      debug 'creating connection object'

      @host = host
      @user = cred[:user]
      @password = cred[:password]
      @connection_unavailable = false

      @logger = logger
    end

    def establish_connection
      debug 'attempting connection'
    end

    def value_at(request)
      debug "issuing request for a single value (#{request[0..30]}...)"
    end

    def values_at(request)
      debug "issing request for multiple values (#{request[0..30]}...)"
    end

    def close
      debug 'closing connection to host'
    end
  end
end
