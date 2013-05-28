# 1.0.3
* Added support for F5 Big-IP traffic manager appliances
* Added support for Cisco IOS devices
* Added support for Brocade FOS devices
* Added support to handle the automatic closing of SSH connections by Cisco appliances
* Added more error support for SSH connections
* Added new helper methods to String class
* Added subclasses for each operating system type
* Moved core extension classes to own directory
* Solaris: Fixed bug where interfaces without hardware were causing error
* Windows: Fixed filesystem utilization numbers

# 1.0.2
* Fix for devices asking for password when connecting via SSH
* Fixed return value for Target#connect
* Added #failure_message to connectors
* Added registry subkey and value caching for WMI connections
* Added constants for connection failures, changed logging messages for connectors
* Changed all eval calls to Object.send
* Various bug fixes

# 1.0.1
* Renamed Profiles to Profilers
* Moved networking helper methods to newly created Network module
* Separated Structure and Profilers
* Profilers are now separate classes for easier subclassing
* Simplified logging

# 1.0.0.beta1
* Initial public release

# 1.0.0* was yanked
