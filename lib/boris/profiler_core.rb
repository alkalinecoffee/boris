require 'boris/structure'

module Boris; module ProfilerCore
  include Lumberjack
  include Structure

  attr_reader :cache

  def initialize(connector)
    @host = connector.host
    @logger = Boris.logger
    @connector = connector
    @cache = {:users=>[]}
  end
end; end