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

  PORT_DEFAULTS           = {:ssh=>22, :wmi=>135}
  VALID_CONNECTION_TYPES  = [:snmp, :ssh, :wmi]

  CONN_FAILURE_AUTH_FAILED        = 'authentication failed'
  CONN_FAILURE_HOST_KEY_MISMATCH  = 'connection failed (ssh: host key mismatch)'
  CONN_FAILURE_NO_HOST            = 'connection failed (no such host)'
  CONN_FAILURE_RPC_FILTERED       = 'connection failed (wmi: rpc calls canceled by remote message filter)'
  CONN_FAILURE_RPC_UNAVAILABLE    = 'connection failed (wmi: rpc server unavailable)'
  CONN_FAILURE_LOCAL_CREDENTIALS  = 'connection failed (wmi: credentials used locally, will try again)'
  CONN_FAILURE_PASSWORD_EXPIRED   = 'connection failed (password expired, requires changing)'
  CONN_FAILURE_REFUSED            = 'connection failed (target actively refused the connection)'
end