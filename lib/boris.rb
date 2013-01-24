# encoding: UTF-8

PLATFORM = :win32 if RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/

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

require 'boris/errors'
require 'boris/options'
require 'boris/target'

require 'boris/helpers/array'
require 'boris/helpers/constants'
require 'boris/helpers/hash'
require 'boris/helpers/scrubber'
require 'boris/helpers/string'

module Boris

end