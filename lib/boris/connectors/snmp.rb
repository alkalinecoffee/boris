require 'boris/connectors'

module Boris
  class SNMPConnector < Connector
    def initialize(host, cred, options, logger=nil)
      super(host, cred, options, logger)
      @snmp_options = options[:snmp_options].merge(:host=>@host, :version=>:SNMPv1, :community=>@user)

      #snmp connections are always reconnectable
      @reconnectable = true
    end

    def establish_connection
      super

      begin
        @transport = SNMP::Manager.new(@snmp_options)
        value_at('sysDescr')
        debug 'connection established'
        @connected = true
      rescue SNMP::RequestTimeout
        warn 'connection failed (connection timeout)'
      end

      return self
    end

    def value_at(request)
      values_at(request, 1)[0]
    end

    def values_at(request, limit=nil)
      super(request, limit)

      return_data = []

      @transport.walk(request) do |row|
        row.each {|item| return_data << {:name=>item.name.to_s, :value=>item.value}}
      end

      info "#{return_data.size} row(s) returned"

      limit = return_data.size if limit.nil?

      return_data[0..limit]
    end
  end
end