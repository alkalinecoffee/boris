require 'boris/structure'
require 'boris/helpers'

module Boris; module Profilers
  class Profiler
    include Lumberjack
    include Structure

    def initialize(connector)
      @host = connector.host
      @logger = Boris.logger
      @connector = connector
    end
  end
end; end