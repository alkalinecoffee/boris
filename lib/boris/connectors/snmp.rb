require 'boris/connectors'

module Boris
  class SNMPConnector < Connector
    def initialize(target_name, cred, options, logger=nil)
      super(target_name, cred, options, logger)
      @snmp_options = options[:snmp_options].merge(:host=>@target_name, :version=>:SNMPv1, :community=>@user)
    end

    def establish_connection
      super

      begin
        @transport = SNMP::Manager.new(@snmp_options)
        value_at('sysDescr')
        debug 'connection established'
      rescue SNMP::RequestTimeout
        warn 'connection failed (connection timeout)'
      end

      return self
    end

    def value_at(request)
      values_at(request).first
    end

    def values_at(request)
      super(request)

      return_data = []

      @transport.walk(request) do |row|
        row.each {|item| return_data << {:name=>item.name.to_s, :value=>item.value}}
      end

      info "#{return_data.size} values returned"

      return_data
    end
  end
end