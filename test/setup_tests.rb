$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'shoulda'
require 'mocha'
require 'boris'

include Boris

class ProfilerTestSetup < Test::Unit::TestCase
  def initialize(test)
    super(test)
    @target = Target.new('0.0.0.0')
  end
end