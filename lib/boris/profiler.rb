require 'boris/structure'

require 'boris/helpers/array'
require 'boris/helpers/hash'
require 'boris/helpers/string'

module Boris; module Profilers
  class Profiler
    include Boris::Structure
    
    def initialize(connector, logger=nil)
      @connector = connector
      @logger = logger
    end
  end
end; end