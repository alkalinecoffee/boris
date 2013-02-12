require 'boris/structure'

require 'boris/helpers/array'
require 'boris/helpers/hash'
require 'boris/helpers/string'

module Boris; module Profilers
  class Profiler
    include Boris::Structure
    
    def initialize(connector)
      @connector = connector
      @logger = Boris.logger
    end
  end
end; end