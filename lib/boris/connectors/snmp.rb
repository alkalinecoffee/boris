require 'boris/connectors'

module Boris
  class SNMPConnector < Connector
    
    # Create an instance of SNMPConnector by passing in a mandatory hostname or IP address,
    # credential to try, and optional Hash of {Boris::Options options}.  Under the hood, this
    # class uses the SNMP library.
    #
    # @param [String] host hostname or IP address
    # @param [Hash] credential credential we wish to use
    # @param [Hash] options an optional list of options. See {Boris::Options} for a list of all
    #   possible options.  The relevant option set here would be :snmp_options.
    def initialize(host, cred, options)
      super(host, cred, options)
      @snmp_options = options[:snmp_options].merge(:host=>@host, :version=>:SNMPv1, :community=>@user)

      #snmp connections are always reconnectable
      @reconnectable = true
    end

    # Disconnect from the host.
    def disconnect
      super
      @transport = nil
      debug 'connections closed'
    end

    # Establish our connection.
    # @return [SNMPConnector] instance of SNMPConnector
    def establish_connection
      super

      begin
        @transport = SNMP::Manager.new(@snmp_options)
        value_at('sysDescr')
        debug 'connection established'
        @connected = true
      rescue SNMP::RequestTimeout
        warn 'connection failed (connection timeout)'
      rescue => error
        warn "connection failed (#{error.message})"
      end

      self
    end

    # Return a single value from our request.
    # @param [String] request the command we wish to execute over this connection
    # @return [String] the first row/line returned by the host
    def value_at(request)
      values_at(request, 1)[0]
    end

    # Return multiple values from our request, up to the limit specified (or no
    # limit if no limit parameter is specified.
    # @param [String] request the command we wish to execute over this connection
    # @param [Integer] limit the optional maximum number of results we wish to return
    def values_at(request, limit=nil)
      super(request, limit)

      return_data = []

      @transport.walk(request) do |row|
        row.each {|item| return_data << {:name=>item.name.to_s, :value=>item.value}}
      end

      debug "#{return_data.size} row(s) returned"

      limit = return_data.size if limit.nil?

      return_data[0..limit]
    end
  end
end