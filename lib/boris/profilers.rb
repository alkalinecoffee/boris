module Boris; module Profilers
  class Profiler
    def initialize(connector, logger=nil)
      @connector = connector
      @logger = logger
    end
  end
end; end