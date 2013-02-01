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

  # Boris is a library that facilitates the communication between you and various networked devices
  # over SNMP, SSH and WMI, pulling a large amount of configuration items including installed software,
  # network settings, serial numbers, user accounts, disk utilization, and more.

  # Out of the box, Boris has server support for Windows, Red Hat, and Solaris (with other platforms
  # available with future plugins), with a focus on returning precisely formatted data, no matter
  # which platforms your organization may have deployed.  Through the use of profiles, Boris can easily
  # be extended by the developer to include other platforms.  Highly suitable for small and large
  # environments alike looking to pull configuration data from various platforms.

  
end