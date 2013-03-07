require 'boris/structure'
require 'boris/helpers'

module Boris; module Profilers
  class Profiler
    include Lumberjack
    include Structure

    attr_reader :cache

    def initialize(connector)
      @host = connector.host
      @logger = Boris.logger
      @connector = connector
      @cache = {:users=>[]}
    end
  end
end; end