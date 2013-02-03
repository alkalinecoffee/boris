require 'boris/connectors'

module Boris
  class SSHConnector < Connector
    def initialize(host, cred, options, logger=nil)
      @ssh_options = options[:ssh_options]
      @ssh_options[:password] = @password if @password

      invalid_ssh_options = @ssh_options.keys - Net::SSH::VALID_OPTIONS
      raise ArgumentError, "invalid ssh option(s): #{invalid_ssh_options.join(', ')}" if invalid_ssh_options.any?

      super(host, cred, options, logger)
    end

    def disconnect
      super
      @transport = nil
      debug 'connections closed'
    end
    
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

      return self
    end

    def value_at(request, request_pty=false)
      values_at(request, request_pty, 1)[0]
    end
    
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

      info "#{return_data.size} row(s) returned"

      limit = return_data.size if limit.nil?

      return_data[0..limit]
    end
  end
end