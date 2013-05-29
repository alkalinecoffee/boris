# Boris
## Networked-device scanning library written in Ruby

* Code: http://github.com/alkalinecoffee/boris
* Developer's blog: http://www.sharkwavemedia.com
* Documentation: http://rdoc.info/github/alkalinecoffee/boris/frames
* Issues: https://github.com/alkalinecoffee/boris/issues

## Introduction
Boris is a library that facilitates the communication between you and various networked devices over SNMP, SSH and WMI, pulling a large amount of configuration items including installed software, network settings, serial numbers, user accounts, disk utilization, and more.

Out of the box, Boris has server support for Red Hat, Solaris, and Windows, as well as support for Big-IP traffic managers, with a focus on returning precisely formatted data, no matter which platforms your organization may have deployed.  Through the use of profilers, Boris can easily be extended by the developer to include other platforms.  Highly suitable for small and large environments alike looking to pull configuration data from various platforms connected to their network.

## Features
* Server support: Red Hat Linux, Solaris, and Windows (support for OS X in the works)
* Appliance support: F5 BIG-IP (support for Cisco IOS & NX-OS devices in the works)
* Utilizes SSH and WMI communication technologies (SNMP is baked in but not currently used)
* Expandable to include other networked devices, such as switches, load balancers, and other appliances and server operating systems

## Installation
    gem install boris

Or if using Bundler, add to your Gemfile

    gem 'boris'

## Example
Let's pull some information from a Red Hat Enterprise Linux server on our network:

```ruby
require 'boris'

Boris.log_level = :debug

hostname = 'redhatserver01.mydomain.com'

# let's use a helper to suggest how we should connect to it (if we're not sure what kind of device this is)
puts Boris::Network.suggested_connection_method(hostname)

# you can also add the logic to make the decision yourself
puts Boris::Network.tcp_port_responding?(hostname, 22)

target = Boris::Target.new(hostname)

target.options.add_credential(:user=>'myusername', :password=>'mypassword', :connection_types=>[:ssh])

# if this is a host using SSH, we can also pass in Net::SSH options (such as a private key for
# authentication). SSH options passed to Boris will automatically be passed to Net:SSH. Likewise for
# Net::SNMP--options passed to :snmp_options will be passed to the Net::SNMP library.
target.options[:ssh_options] = {:keys=>['/path/to/my/private/key']}

target.connect

if target.connected?
  # we can try to detect which profiler to load up (is this target running windows? solaris? or
  # what?).  if we can't detect a suitable profiler, this will throw an error.
  target.detect_profiler

  puts target.profiler.class

  # we can call individual methods to grab specific information we may be interested in
  target.get(:hardware)
  target.get(:network_interfaces)

  # retrieved items can be referenced two ways:
  puts target[:network_interfaces].inspect
  puts target.profiler.network_interfaces.inspect

  # we can also call #retrieve_all to grab everything we can from this target (file systems, hardware,
  # installed applications, etc.)
  target.retrieve_all

  puts target.to_json(:pretty_print)

  target.disconnect
end
```

## Sample Output
```ruby
target.get(:hardware)
target.get(:operating_system)

target.scrub_data!

puts target[:hardware]
  #=>{
  #    :cpu_architecture=>64,
  #    :cpu_core_count=>2,
  #    :cpu_model=>'AMD Opteron Processor 6174',
  #    :cpu_physical_count=>1,
  #    :cpu_speed_mhz=>2200,
  #    :cpu_vendor=>'AMD, Inc.',
  #    :firmware_version=>'6.0',
  #    :model=>'VMware Virtual Platform',
  #    :memory_installed_mb=>1024,
  #    :serial=>'VMware-1234',
  #    :vendor=>'VMware, Inc.'
  #  }

puts target[:operating_system]
  #=>{
  #    :date_installed=>#<DateTime: 2013-02-04T19:08:49-05:00 ((2456329j,529s,891979000n),-18000s,2299161j)>,
  #    :features=>[],
  #    :kernel=>'5.2.3790',
  #    :license_key=>'BBBBB-BBBBB-BBBBB-BBBBB-BBBBB',
  #    :name=>'Microsoft Windows',
  #    :roles=>['TerminalServer', 'TimeServer'],
  #    :service_pack=>'Service Pack 2',
  #    :version=>'Server 2003 R2 Standard'
  #  }
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
* **local users and groups** - local groups and the users within each
* **network ID** - hostname and domain
* **network interfaces** - ethernet and fibre channel interfaces, including IPs, MAC addresses, connection status
* **operating system** - name, version, kernel, date installed
* **running processes** - process command, start time and cpu time

See [Boris::Profilers::Structure](http://www.rubydoc.info/github/alkalinecoffee/boris/Boris/Profilers/Structure) for more details on the data structure.

Because the commands that might work correctly on one type of platform most likely won't work on another, Boris handles this by the use of...

## Profilers
Profilers contain the instructions that allow us to run commands against our target and then parse and make sense of the data.  Boris comes with the capability to communicate with targets over SNMP, SSH, or WMI.  Each profiler is written to use one of these methods of communication (internally called 'connectors'), which serve as a vehicle for running commands against a server.  Boris comes with a few profilers built-in for some popular platforms, but can be easily extended to include other devices.

**Available profilers:**

* **[Big-IP Core](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/BigIP)**
  * [Big-IP v10](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/BigIP10)
  * [Big-IP v11](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/BigIP11)
* **[Linux Core](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/Linux)**
  * [Red Hat Enterprise Linux 5](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/RHEL5)
  * [Red Hat Enterprise Linux 6](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/RHEL6)
* **[UNIX Core](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/UNIX)**
  * [Oracle Solaris 10](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/Solaris10)
  * [Oracle Solaris 11](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/Solaris11)
* **[Windows Core](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/Windows)**
  * [Windows 2003 Server](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/Windows2003)
  * [Windows 2008 Server](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/Windows2008)
  * [Windows 2012 Server](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Profilers/Windows2012)

Run [Boris#available_profilers](http://www.rubydoc.info/github/alkalinecoffee/boris/Boris.available_profilers).

## Extending Boris

#### Running your own commands

You can also run your own commands to grab information off of systems.  For example, on a Linux device, to run your own script that is already on the target and retrieve its output:

```ruby
# use the target's connector to grab multiple values.  #values_at will return an array with each line
# returned as an item in the returned array.
multiple_lines_of_data = target.connector.values_at('/path/to/some/script')

# to grab only the first line from a script or file, you can use #value_at:
single_line_of_data = target.connector.value_at('/path/to/some/script')
```

Running commands in this fashion utilizes the #exec method from the Net::SSH library.

For a Windows host, which uses WMI vice SSH, you can send WMI queries or registry keys to the connector to get information:

```ruby
# this will pull rows from a class in the standard root\CIMV2 namespace, returning an array of hashes
multiple_rows_of_data = target.connector.values_at('SELECT * FROM Win32_NetworkAdapter')

# this will pull rows from a class in the lower-level root\WMI namespace (note the second argument we're
# passing to #values_at):
multiple_rows_of_data = target.connector.values_at('SELECT * FROM MSNdis_EnumerateAdapter', :root_wmi)

# poll registry keys under HKEY_LOCAL_MACHINE by providing a base key path, which returns an array of keys:
registry_keys = target.connector.registry_subkeys_at('SOFTWARE\Microsoft\Windows')

# grab values found at some key via #registry_values_at, which returns value/data elements in a Hash:
registry_values = target.connector.registry_values_at('SOFTWARE\Microsoft\Windows\CurrentVersion')
```

#### Creating your own profiler

More than likely, you may want to grab information off of a platform that is not supported by Boris.  It's easy to create your own profiler by using the profiler skeleton file located in the `skeleton` directory.  Simply copy the `profiler_skeleton` file to your app's directory with a `.rb` extension, and modify that file to run the proper commands and retrieve the data from your desired platform, writing the data into the already available instance variables.  Once your data retrieval methods are set, simply require your newly created file in your app, and add the class to your `Target#options[:profilers]` array, and it will be available to you.

Some recommendations on making your own profiler:
* Create a core file (ex. WindowsCore) for your platform, and only place generalized data-retrieval methods in this file if they would apply to the majority of versions available to that platform
* Create a new profiler file for each version of your platform (ie. Windows2012), using the core class as its parent class
  * Name your version classes with the major version number applied
  * Only use code that applies to that specific version in your version profiler files
  * Each version file should include a class method called `matches_target?`, where the logic will be to determine if this specific profiler version matches that of the device you're communicating with
* Stick with the built-in variable names, and use the templates as described in [structure.rb](http://rubydoc.info/github/alkalinecoffee/boris/master/Boris/Structure), and extend them as necessary.
* Be consistent by always calling `super` on your data-retrieval methods and ending the method by returning the data variable, even if that method does not apply to that platform
* Check out the available helpers in the `lib/boris/core_ext` directory (especially those in [string.rb](http://rubydoc.info/github/alkalinecoffee/boris/master/String)!)
* See the profilers in the `lib/boris/profilers` directory for more guidance

Also, please consider a pull request if you think your code can help others!

## System Requirements
While Boris does its best to gather data from devices without any special privileges, sometimes it just can't be helped.  One example of this is the `RedHat` profiler, which requires `sudo` access for the `dmidecode` command, as there isn't a well known, reliable way to grab hardware info without `dmidecode`.  If Boris attempts to run a command that requires special access and is denied, it will throw a message to the logger and move on.

**Here is a list of known scan account requirements for each platform:**

* **Big-IP**
  * User shell set to `tmsh`
* **Linux (any flavor)**
  * User must have `sudo` for `dmidecode`
* **Solaris**
  * User must have `sudo` for `fcinfo`
* **Windows**
  * User must be a member of local Administrator group (looking into what other groups provide required access)

## Contributing
If you have written a profiler (and tests) for a device not currently supported, please create a pull request for it.  Also, my testing sucks, so if anyone wants to help clean that up, I'm all about it.

## License
This software is provided under the MIT license.  See the LICENSE.md file.