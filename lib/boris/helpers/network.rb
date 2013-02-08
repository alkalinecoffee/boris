require 'boris/lumberjack'

module Boris
  module Network
    include Lumberjack

    # Attempts to suggest a connection method based on whether certain TCP ports
    # on the target are responding (135 for WMI, 22 for SSH by default).  Can be
    # used to speed up the process of determining whether we should try to
    # connect to our host using different methods, or bypass certain attempts
    # entirely.
    #
    #  Boris::NetTools.suggested_connection_method('linuxserver01') #=> :ssh
    #
    # @param target name we wish to test against
    # @return [Symbol] returns :wmi, :ssh, or nil
    # @see tcp_port_responding?
    def self.suggested_connection_method(target)
      connection_method = nil
      
      PORT_DEFAULTS.each_pair do |key, val|
        break if connection_method
        
        #debug "detecting if #{key.to_s} is available"

        if tcp_port_responding?(target, val)
          #debug "#{key.to_s} seems to be available"
          connection_method = key
        else
          #info 'wmi does not appear to be responding'
        end
      end

      #info 'failed to detect connection method' if connection_method.nil?
      connection_method
    end

    # Checks if the supplied TCP port is responding on the target.  Useful for
    # determining which connection type we should use instead of taking more
    # time connecting to the target using different methods just to check if
    # they succeed or not.
    #
    #  Boris::NetTools.tcp_port_responding?('windowsserver01', 22)  #=> false
    #
    # @param target name we wish to test against
    # @param port the TCP port number we wish to test
    # @return [Boolean] returns true of the supplied port is responding
    def self.tcp_port_responding?(target, port)
      status = false

      #debug "checking if port #{port} is responding"

      begin
        conn = TCPSocket.new(target, port)
        #info "port #{port} is responding"
        conn.close
        #debug "connection to port closed"
        status = true
      rescue
        #info "port #{port} is not responding"
        status = false
      end

      status
    end
  end
end