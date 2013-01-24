require 'boris/connectors'

module Boris
  class SSHConnector < Connector
    def initialize(host, cred, options, logger=nil)
      super(host, cred, options, logger)

      @ssh_options = options[:ssh_options]
      @ssh_options[:password] = @password if @password
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
      
      return_data = []
      
      reconnect = false

      chan = @transport.open_channel do |chan|
        chan.on_data do |ch, data|
          if request =~ /^sudo / && data =~ /password for/i
            warn "target is asking for password on request (#{request})"
          elsif data =~ /permission denied/i
            warn "permission denied within request (#{request})... #{data}"
          else
            return_data << data
          end
        end
        
        # called when something is written to stderr
        chan.on_extended_data do |ch, type, data|
          warn "message written to STDERR on request (#{request})... #{data}"
        end

        chan.on_close do |ch|
          # channel was closed, typically done by cisco switches... so we'll quietly reconnect later
          info 'channel closed prematurely (will reconnect)'
          reconnect = true
        end
        
        if request_pty
          debug 'requsting pty'
          chan.request_pty()
          debug 'pty successfully requested'
        end

        chan.exec(request)
      end

      chan.wait

      info "#{return_data.size} row(s) returned"
      
      if reconnect
        debug 'preparing to refresh connection'
        establish_connection
      end

      limit = return_data.size if limit.nil?

      return_data[0..limit]
    end
  end
end