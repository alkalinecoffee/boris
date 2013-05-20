STDOUT.sync = true
require 'boris/connectors'

module Boris
  class SSHConnector < Connector

    # Create an instance of SSHConnector by passing in a mandatory hostname or IP address,
    # credential to try, and optional Hash of {Boris::Options options}.  Under the hood, this
    # class uses the Net/SSH library.
    #
    # @param [String] host hostname or IP address
    # @param [Hash] cred credential we wish to use
    # @param [Hash] options an optional list of options. See {Boris::Options} for a list of all
    #   possible options.  The relevant option set here would be :ssh_options.
    def initialize(host, cred, options=Options.new)
      super(host, cred)

      @ssh_options = options[:ssh_options]

      @reconnect_mode = false
      
      if @ssh_options
        invalid_ssh_options = @ssh_options.keys - Net::SSH::VALID_OPTIONS
        raise ArgumentError, "invalid ssh option(s): #{invalid_ssh_options.join(', ')}" if invalid_ssh_options.any?
      end

      @ssh_options[:auth_methods] = ['publickey']
      if @password
        @ssh_options[:auth_methods] << 'password'
        @ssh_options[:password] = @password
      end
    end

    # Disconnect from the host.
    def disconnect
      super

      @transport.close rescue nil
      @transport = nil
      
      debug 'connections closed'
    end
    
    # Establish our connection.
    # @return [SSHConnector] instance of SSHConnector
    def establish_connection
      super

      @connected = @reconnectable = false

      begin
        @transport = Net::SSH.start(@host, @user, @ssh_options)

        # send a newline character to test if the connection is ok. if the return value
        # is nil, then the connection should be good.
        if @reconnect_mode == false
          test_result = value_at("\n")
          
          raise PasswordExpired, @failure_messages.last if (test_result && test_result =~ /password has expired/i)
          
          debug 'connection established'
        else
          debug 'connection re-established'
        end
        
        @connected = @reconnectable = true
      rescue Net::SSH::AuthenticationFailed
        warn "connection failed (connection made but credentials not accepted with user #{@user})"
        @failure_messages << CONN_FAILURE_AUTH_FAILED
        @reconnectable = true
      rescue Net::SSH::HostKeyMismatch
        warn CONN_FAILURE_HOST_KEY_MISMATCH
        @failure_messages << CONN_FAILURE_HOST_KEY_MISMATCH
      rescue SocketError, Errno::ETIMEDOUT
        warn CONN_FAILURE_NO_HOST
        @failure_messages << CONN_FAILURE_NO_HOST
      rescue Errno::ECONNREFUSED
        warn CONN_FAILURE_REFUSED
        @failure_messages << CONN_FAILURE_REFUSED
      rescue Boris::PasswordExpired
        warn CONN_FAILURE_PASSWORD_EXPIRED
        @failure_messages << CONN_FAILURE_PASSWORD_EXPIRED
      rescue Net::SSH::Disconnect
        warn CONN_FAILURE_CONNECTION_CLOSED
        @failure_messages << CONN_FAILURE_CONNECTION_CLOSED
      rescue => error
        @failure_messages << "connection failed (#{error.message})"
        warn @failure_messages.last
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
    # limit if no limit parameter is specified.
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

      if @reconnect_mode
        disconnect
        establish_connection
      end
      
      channel = @transport.open_channel do |chan, success|
        debug 'channel opened successfully' if success

        if request_pty
          debug 'requsting pty...'
          chan.request_pty()
          debug 'pty successfully requested'
        end

        chan.exec(request) do |chan, success|
          chan.on_data do |chan, data|
            if data =~ /^\[sudo\] password for/i
              debug 'system asking for password for sudo request'
              if @password
                chan.send_data "#{@password}\n"
                debug 'password sent'
              else
                chan.close
                info "channel closed (we don't have a password to supply)"
              end
            elsif data =~ /sorry, try again/i
              chan.close
              return_data = []
              info 'channel closed (we have a password to supply but it is not accepted)'
            elsif data =~ /permission denied/i
              warn "permission denied for this request (#{data.gsub(/\n|\s+/, ', ')})"
            else
              return_data << data
            end
          end

          chan.on_extended_data do |chan, data|
            if data =~ /password has expired/i
              @failure_messages << CONN_FAILURE_PASSWORD_EXPIRED
              chan.close
              disconnect
            end
            error_messages.concat(data.split(/\n/))
          end
        end
      end

      begin
        channel.wait
      rescue Net::SSH::Disconnect
        # some devices (namely cisco switches) tend to silently break the ssh
        # connection after creating a session and running a command. to get around
        # this, we will re-establish the connection (and bypassing our test command
        # in #establish_connection) to prepare the connection for running another
        # command.
        info 'connection broken by remote host... we will automatically reconnect'
        @reconnect_mode = true
      end

      if !error_messages.empty?
        warn "message written to STDERR for this request (#{error_messages.join('. ')})"
      end

      return_data = return_data.join.gsub(/\r/, '').split(/\n/)

      limit = return_data.size if limit.nil?
      
      debug "#{return_data.size} row(s) returned"

      return_data[0..limit]
    end
  end
end