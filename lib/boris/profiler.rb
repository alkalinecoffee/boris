require 'boris/structure'

require 'boris/helpers/array'
require 'boris/helpers/hash'
require 'boris/helpers/string'
require 'boris/helpers/scrubber'

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