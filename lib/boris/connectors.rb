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
      @connected = false
      @reconnectable = true

      @logger = logger
    end

    def connected?
      @connected
    end

    def disconnect
      debug 'closing connection to host'
      @connected = false
    end

    def establish_connection
      debug 'attempting connection'
    end

    def values_at(request, limit)
      if !limit.kind_of?(Integer)
        raise ArgumentError, "non-integer limit specified (#{limit.inspect})"
      elsif limit < 1
        raise ArgumentError, "specified limit must be greater than 1 (or nil for no limit) (#{limit.inspect})"
      end unless limit.nil?

      amount = limit == 1 ? 'single value' : 'multiple values'

      debug "issuing request for #{amount} (#{request.inspect})"
    end
  end
end
