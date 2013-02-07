module Boris
  module NetTools
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
    def suggested_connection_method(target)
      connection_method = nil
      
      debug 'detecting if wmi is available'
      connection_method = :wmi if tcp_port_responding?(target, PORT_DEFAULTS[:wmi])
      info 'wmi does not appear to be responding'

      if connection_method.nil?
        debug 'detecting if ssh is available'
        connection_method = :ssh if tcp_port_responding?(target, PORT_DEFAULTS[:ssh])
        info 'ssh does not appear to be responding'
      end

      info 'failed to detect connection method' if connection_method.nil?
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
    def tcp_port_responding?(target, port)
      status = false

      debug "checking if port #{port} is responding"

      begin
        conn = TCPSocket.new(target, port)
        info "port #{port} is responding"
        conn.close
        debug "connection to port closed"
        status = true
      rescue
        info "port #{port} is not responding"
        status = false
      end

      status
    end
  end
end