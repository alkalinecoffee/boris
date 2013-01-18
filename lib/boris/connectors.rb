module Boris
  class Connector
    include Lumberjack

    attr_reader :options
    attr_reader :host

    def initialize(host, cred, options, logger=nil)
      @host = host
      @user = cred[:user]
      @password = cred[:password]
      @connection_unavailable = false

      self.logger = logger

      debug 'creating connection object'
    end

    def establish_connection
      debug 'attempting connection'
    end

    def value_at(request)
      debug "preparing to issue request for a single value (#{request})"
    end

    def values_at(request)
      debug "preparing to issue request for multiple values (#{request})"
    end

    def close
      debug 'closing connection'
    end
  end
end
