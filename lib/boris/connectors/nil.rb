require 'boris/connectors'

module Boris
  class NilConnector < Connector
    def initialize
      debug 'creating dormant connection object'
      @connected = false
    end
  end
end