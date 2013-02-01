# Boris
## A networked-device scanning solution

* Code: http://github.com/alkalinecoffee/boris
* Issues: https://github.com/alkalinecoffee/boris/issues

## Introduction
Boris is a library that facilitates the communication between you and various networked devices over SNMP, SSH and WMI, pulling a large amount of configuration items including installed software, network settings, serial numbers, user accounts, disk utilization, and more.

Out of the box, Boris has server support for Windows, Red Hat, and Solaris (with other platforms available with future plugins), with a focus on returning precisely formatted data, no matter which platforms your organization may have deployed.  Through the use of profiles, Boris can easily be extended by the developer to include other platforms.  Highly suitable for small and large environments alike looking to pull configuration data from various platforms.

## Features
* Out of the box, pulls information from RedHat Linux, Solaris 10, and Windows servers
* Utilizes SNMP, SSH, and WMI communication technologies
* Expandable to include other networked devices, such as switches, load balancers, and other operating systems

## Installation
    gem install boris

## Example
Let's pull some information from a RedHat Enterprise Linux server on our network:

```ruby
require 'boris'

target = Boris::Target.new('redhatserver01.mydomain.com')

# let's use a helper to suggest how we should connect to it (which is useful if we're not sure what
# kind of device this is)
puts target.suggested_connection_method

# you can also add the logic to make the decision yourself by checking if certain TCP ports are responsive
puts target.tcp_port_responding?(22)

# add credentials to try against this target
target.options.add_credential(:user=>'joe', :password=>'mypassword', :connection_types=>[:ssh])

# attempt to connect to this target using the credentials we supplied above
target.connect

if target.connected?
  # detect which profile to load up (is this target running windows? solaris? or what?).  if we can't
  # detect a suitable profile, this will throw an error
  target.detect_profile

  puts target.target_profile

  # we can call individual methods to grab specific information we may be interested in (or call
  # #retrieve_all to grab everything we can)
  target.get_hardware

  puts target.hardware.inspect

  # finally, we can package up all of the data into json format for portability
  puts target.to_json
end

target.disconnect
```

## Data
Through a number of queries and algorithms, Boris effeciently polls devices on the network for information including, but not limited to, network configuration, hardware capabilities, installed software and services, applied hotfixes/patches, and more.
#### Available methods for use on most platforms include:
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

Because the commands that might work correctly on one type of platform most likely won't work on another, Boris handles this by the use of...

## Profiles
Profiles contain the instructions that allow us to run commands against our target and then parse and make sense of the data.  Boris comes with the capability to communicate with targets over SNMP, SSH, or WMI.  Each profile is written to use one of these methods of communication (internally called 'connectors'), which serve as a vehicle for running commands against a server.  Boris comes with a few profiles built-in for some popular platforms, but can be easily extended to include other devices.

## Requirements
* Ruby 1.9.3 (only tested on MRI)
* Net/SSH gem
* NetAddr gem
* SNMP gem
* Mocha (for tests only)
* Shoulda (for tests only)

## LICENSE
This software is provided under the MIT license.  See the LICENSE.md file.