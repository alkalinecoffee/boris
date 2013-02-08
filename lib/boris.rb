# encoding: UTF-8

PLATFORM = RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/ ? :win32 : RbConfig::CONFIG['host_os']

require 'date'
require 'json'
require 'logger'
require 'netaddr'
require 'net/ssh'
require 'rbconfig'
require 'snmp'
require 'socket'
require 'thread'
require 'win32ole' if PLATFORM == :win32

require 'boris/lumberjack'
require 'boris/target'

module Boris
  @logger = BorisLogger.new(STDOUT)
  @logger.level = Logger::FATAL

  def self.logger
    @logger
  end
end