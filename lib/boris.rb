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

require 'boris/helpers/array'
require 'boris/helpers/constants'
require 'boris/helpers/hash'
require 'boris/helpers/net_tools'
require 'boris/helpers/scrubber'
require 'boris/helpers/string'

require 'boris/errors'
require 'boris/options'
require 'boris/target'

module Boris
end