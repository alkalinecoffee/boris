$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'shoulda'
require 'mocha/setup'
require 'boris'

include Boris

class ProfilerTestSetup < Test::Unit::TestCase
  def initialize(test)
    super(test)
    @host = '0.0.0.0'
    @target = Target.new(@host)
  end
end