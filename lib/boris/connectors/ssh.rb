require 'boris/connectors'

module Boris
  class SSHConnector < Connector
    def initialize(target_name, cred, options, logger=nil)
      super(target_name, cred, options, logger)

      @ssh_options = options[:ssh_options]
      @ssh_options[:password] = @password if @password
    end
    
    def establish_connection
      super

      begin
        @transport = Net::SSH.start(@target_name, @user, @ssh_options)
        debug 'connection established'
      rescue Net::SSH::AuthenticationFailed
        warn "connection failed (connection made but credentials not accepted with user #{@user})"
      rescue Net::SSH::HostKeyMismatch
        warn 'connection failed (host key mismatch)'
      rescue Net::SSH::Exception => error
        warn "connection failed (#{error.message})"
      end unless @connection_unavailable

      return self
    end

    def value_at(request, request_pty=false)
      values_at(request, request_pty)[0]
    end
    
    def values_at(request, request_pty=false)
      super(request)
      
      output_buffer = []
      
      reconnect = false

      chan = @transport.open_channel do |chan|
        chan.on_data do |ch, data|
          if request =~ /^sudo / && data =~ /password for/i
            warn "target is asking for password on request (#{request})"
          elsif data =~ /permission denied/i
            warn "permission denied within request (#{request})... #{data}"
          else
            output_buffer << data
          end
        end
        
        # called when something is written to stderr
        chan.on_extended_data do |ch, type, data|
          warn "message written to STDERR on request (#{request})... #{data}"
        end

        chan.on_close do |ch|
          # channel was closed, typically done by cisco switches... so we'll quietly reconnect later
          debug 'channel closed prematurely (will reconnect)'
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
      debug 'data received successfully'
      
      if reconnect
        debug 'preparing to refresh connection'
        establish_connection
      end

      output_buffer
    end
  end
end