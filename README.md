# Boris
## Networked-device scanning library written in Ruby

* Code: http://github.com/alkalinecoffee/boris
* Developer's blog: http://www.sharkwavemedia.com
* Documentation: http://rdoc.info/github/alkalinecoffee/boris/master/frames
* Issues: https://github.com/alkalinecoffee/boris/issues

## Introduction
Boris is a library that facilitates the communication between you and various networked devices over SNMP, SSH and WMI, pulling a large amount of configuration items including installed software, network settings, serial numbers, user accounts, disk utilization, and more.

Out of the box, Boris has server support for Windows, Red Hat, and Solaris (with other platforms available with future plugins), with a focus on returning precisely formatted data, no matter which platforms your organization may have deployed.  Through the use of profilers, Boris can easily be extended by the developer to include other platforms.  Highly suitable for small and large environments alike looking to pull configuration data from various platforms.

## Features
* Currently, pulls information from RedHat Linux, Solaris 10, and Windows servers (support for OS X, F5 BIG-IP, and Cisco IOS devices in the works)
* Utilizes SNMP, SSH, and WMI communication technologies
* Expandable to include other networked devices, such as switches, load balancers, and other operating systems

## Installation
    gem install boris

## Example
Let's pull some information from a RedHat Enterprise Linux server on our network:

```ruby
require 'boris'

hostname = 'redhatserver01.mydomain.com'

# Boris has different levels of logging.  We can optionally set our logging level, which will apply
# to all Targets created during this session.  If not set, the log level defaults to :fatal.
Boris.log_level = :debug

# let's use a helper to suggest how we should connect to it (which is useful if we're not sure what
# kind of device this is)
puts Boris::Network.suggested_connection_method(hostname)

# you can also add the logic to make the decision yourself by checking if certain TCP ports are responsive
puts Boris::Network.tcp_port_responding?(hostname, 22)

# create our target
target = Boris::Target.new(hostname)

# add credentials to try against this target
target.options.add_credential(:user=>'myusername', :password=>'mypassword', :connection_types=>[:ssh])

# attempt to connect to this target using the credentials we supplied above
target.connect

if target.connected?
  # we can try to detect which profiler to load up (is this target running windows? solaris? or
  # what?).  if we can't detect a suitable profiler, this will throw an error.
  target.detect_profiler

  puts target.profiler

  # we can call individual methods to grab specific information we may be interested in
  target.get(:hardware)
  puts target[:hardware].inspect

  # or maybe get some network interface info
  target.get(:network_interfaces)
  puts target[:network_interfaces].inspect

  # we can also call #retrieve_all to grab everything we can from this target (file systems, hardware,
  # installed applications, etc.)
  target.retrieve_all

  # if there is more information we want to collect but is not collected by default, we can specify
  # our own commands to run against the target via two methods: #get_values returns an Array (each
  # line returned is an element of the array), or #get_value, which returns a String (just the first
  # line returned from the command)
  puts target.connector.values_at('cat /etc/redhat-release')
  puts target.connector.value_at('uname -a')
  
  # NOTE: if this were a Windows server, you would send WMI queries instead of shell commands, ie:
  #  target.connector.values_at('SELECT * FROM Win32_ComputerSystem')

  # finally, we can package up all of the data into json format for portability
  puts target.to_json

  target.disconnect
end
```

## Data
Through a number of queries and algorithms, Boris efficiently polls devices on the network for information including, but not limited to, network configuration, hardware capabilities, installed software and services, applied hotfixes/patches, and more.

**Available methods for use on most platforms include:**

* **file systems** - file system, mount point, capacity and utilization
* **hardware** - make/model, cpu information, firmware/bios version, serial number
* **hosted shares** - folders shared by the target
* **installed applications** - installed applications and the dates of their installation
* **installed patches** - installed patches/hotfixes and the dates of their installation
* **installed services/daemons** - background services and their startup modes
* **local users and groups** - local groups and the member users within each
* **network ID** - hostname and domain
* **network interfaces** - ethernet and fibre channel interfaces, including IPs, MAC addresses, connection status
* **operating system** - name, version, kernel, date installed

See {Boris::Profilers::Structure} for more details on the data structure.

Because the commands that might work correctly on one type of platform most likely won't work on another, Boris handles this by the use of...

## Profilers
Profilers contain the instructions that allow us to run commands against our target and then parse and make sense of the data.  Boris comes with the capability to communicate with targets over SNMP, SSH, or WMI.  Each profiler is written to use one of these methods of communication (internally called 'connectors'), which serve as a vehicle for running commands against a server.  Boris comes with a few profilers built-in for some popular platforms, but can be easily extended to include other devices.

## User Account Requirements
While Boris does its best to gather data from devices without any special privileges, sometimes it just can't be helped.  One example of this is the RedHat profiler, which requires `sudo` access for the `dmidecode` command, as there isn't a well known, reliable way to grab this info without `dmidecode`.  If Boris attempts to run a command that requires special access and is denied, it will throw a message to the logger and move on.

** Here is a list of known scan account requirements for each platform:**

* Windows
  * User must be a member of local Administrator group (looking into what other groups provide required access)
* Linux (any flavor)
  * User must have sudo for `dmidecode`
* Solaris
  * User must have sudo for `fcinfo`

## License
This software is provided under the MIT license.  See the LICENSE.md file.