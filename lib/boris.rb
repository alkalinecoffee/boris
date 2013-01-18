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
require 'boris/helpers/hash'
require 'boris/helpers/scrubber'
require 'boris/helpers/string'

module Boris

  VENDOR_ADOBE      = 'Adobe Systems, Inc.'
  VENDOR_AMD        = 'AMD, Inc.'
  VENDOR_APC        = 'APC Corp.'
  VENDOR_BROCADE    = 'Brocade Communications Corp.'
  VENDOR_CISCO      = 'Cisco Systems, Inc.'
  VENDOR_CITRIX     = 'Citrix Systems, Inc.'
  VENDOR_DELL       = 'Dell Inc.'
  VENDOR_EMULEX     = 'Emulex Corp.'
  VENDOR_F5         = 'F5 Networks, Inc.'
  VENDOR_HP         = 'Hewlett Packard, Inc.'
  VENDOR_IBM        = 'IBM Corp.'
  VENDOR_INTEL      = 'Intel Corp.'
  VENDOR_MICROSOFT  = 'Microsoft Corp.'
  VENDOR_ORACLE     = 'Oracle Corp.'
  VENDOR_QLOGIC     = 'QLogic Corp.'
  VENDOR_REDHAT     = 'Red Hat Inc.'
  VENDOR_SUSE       = 'SUSE Linux GmbH'
  VENDOR_VMWARE     = 'VMware, Inc.'

end