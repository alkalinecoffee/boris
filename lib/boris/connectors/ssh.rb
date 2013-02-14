require 'boris/connectors'

module Boris
  class SSHConnector < Connector

    # Create an instance of SSHConnector by passing in a mandatory hostname or IP address,
    #   credential to try, and optional Hash of {Boris::Options options}.  Under the hood, this
    #   class uses the Net/SSH library.
    #
    # @param [String] host hostname or IP address
    # @param [Hash] credential credential we wish to use
    # @param [Hash] options an optional list of options. See {Boris::Options} for a list of all
    #   possible options.  The relevant option set here would be :ssh_options.
    def initialize(host, cred, options={})
      @ssh_options = options[:ssh_options]
      @ssh_options[:password] = @password if @password

      if @ssh_options
        invalid_ssh_options = @ssh_options.keys - Net::SSH::VALID_OPTIONS
        raise ArgumentError, "invalid ssh option(s): #{invalid_ssh_options.join(', ')}" if invalid_ssh_options.any?
      end

      super(host, cred)
    end

    # Disconnect from the host.
    def disconnect
      super
      @transport = nil
      debug 'connections closed'
    end
    
    # Establish our connection.
    # @return [SSHConnector] instance of SSHConnector
    def establish_connection
      super

      begin
        @transport = Net::SSH.start(@host, @user, @ssh_options)
        debug 'connection established'
        @connected = @reconnectable = true
      rescue Net::SSH::AuthenticationFailed
        warn "connection failed (connection made but credentials not accepted with user #{@user})"
        @reconnectable = true
      rescue Net::SSH::HostKeyMismatch
        warn 'connection failed (host key mismatch)'
        @reconnectable = false
      rescue => error
        warn "connection failed (#{error.message})"
        @reconnectable = true
      end

      if @reconnectable == true
        info 'connection available for retry'
      elsif @reconnectable == false
        info 'connection does not seem to be available (so we will not retry)'
      end unless @transport

      self
    end

    # Return a single value from our request.
    # @param [String] request the command we wish to execute over this connection
    # @param [Boolean] request_pty if true, we should request psuedo-terminal (PTY).
    #   This is necessary if we are calling a command that uses elevated privileges (sudo).
    # @return [String] the first row/line returned by the host
    def value_at(request, request_pty=false)
      values_at(request, request_pty, 1)[0]
    end
    
    # Return multiple values from our request, up to the limit specified (or no
    #   limit if no limit parameter is specified.
    # @param [String] request the command we wish to execute over this connection
    # @param [Boolean] request_pty if true, we should request psuedo-terminal (PTY).
    #   This is necessary if we are calling a command that uses elevated privileges (sudo).
    # @param [Integer] limit the optional maximum number of results we wish to return
    # @return [Array] an array of rows returned by the command
    def values_at(request, request_pty=false, limit=nil)
      super(request, limit)
      
      error_messages = []
      reconnect = false
      return_data = []
      
      chan = @transport.open_channel do |chan|
        if request_pty
          debug 'requsting pty...'
          chan.request_pty()
          debug 'pty successfully requested'
        end

        chan.on_data do |ch, data|
          if data =~ /^\[sudo\] password for/i
            debug 'system asking for password for sudo request'
            if @password
              ch.send_data "#{@password}\n"
              debug 'password sent'
            else
              ch.close
              info "channel closed (we don't have a password to supply)"
            end
          elsif data =~ /sorry, try again/i
            ch.close
            return_data = []
            info "channel closed (we have a password to supply but system its not accepted)"
          elsif data =~ /permission denied/i
            warn "permission denied for this request (#{data.gsub(/\n|\s+/, ', ')})"
          else
            return_data << data
          end
        end
        
        # called when something is written to stderr
        chan.on_extended_data do |ch, type, data|
          error_messages.concat(data.split(/\n/))
        end

        chan.exec(request)
      end

      chan.wait

      if !error_messages.empty?
        warn "message written to STDERR for this request (#{error_messages.join('. ')})"
      end

      return_data = return_data.join.split(/\n/)

      debug "#{return_data.size} row(s) returned"

      limit = return_data.size if limit.nil?

      return_data[0..limit]
    end
  end
end