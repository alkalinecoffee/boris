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

  PORT_DEFAULTS = {:ssh=>22, :wmi=>135}
  VALID_CONNECTION_TYPES = [:snmp, :ssh, :wmi]
end