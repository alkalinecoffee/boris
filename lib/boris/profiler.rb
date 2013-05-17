require 'boris/structure'
require 'boris/helpers'

module Boris; module Profilers

  def self.available_profilers
    ObjectSpace.each_object(Class).inject([]) do |result, item|
      if item < Base && !(item.to_s =~ /windows/i && PLATFORM != :win32) && item.respond_to?(:matches_target?)
        result << item
      end
      result
    end
  end

  class Base
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