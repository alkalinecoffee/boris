# encoding: UTF-8

PLATFORM = RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/ ? :win32 : RbConfig::CONFIG['host_os']
LIB_PATH = File.expand_path('..', __FILE__)

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

require 'boris/target'

module Boris
  # Returns an array of all profiler classes that are currently available. If this
  # is launched from a non-Windows machine, the Windows-based profilers will not be
  # available.
  #
  # @return [Array] list of profiler classes
  def self.available_profilers
    ObjectSpace.each_object(Class).select{|klass| klass.to_s =~ /profilers/i}.inject([]) do |result, klass|
      if !(klass.to_s =~ /windows/i && PLATFORM != :win32) && klass.respond_to?(:matches_target?)
        result << klass
      end
      result
    end.sort_by {|klass| klass.to_s}
  end
end