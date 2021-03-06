require 'setup_tests'

class LinuxCoreTest < BaseTestSetup
  context 'a Linux target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::LinuxCore)
      @target.force_profiler_to(Profilers::LinuxCore)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with('uname -a').returns('GNU/Linux')
    end

    context 'being scanned' do
      setup do
      end

      context 'for file system information' do
        setup do
          @file_system_data = [
            '/dev/md/dsk/d10|1000|500|/',
            '/dev/md/dsk/d11|2000|1000|/var'
          ]

          @expected_data = [
            {
              :capacity_mb=>1000,
              :file_system=>'/dev/md/dsk/d10',
              :mount_point=>'/',
              :san_storage=>nil,
              :used_space_mb=>500
            },
            {
              :capacity_mb=>2000,
              :file_system=>'/dev/md/dsk/d11',
              :mount_point=>'/var',
              :san_storage=>nil,
              :used_space_mb=>1000
            }
          ]
        end

        should 'return file system information via #get_file_systems' do
          file_system_command = %q{df -P -T | grep "^/" | awk '{print $1 "|" $3 / 1024 "|" $5 / 1024 "|" $7}'}

          @connector.stubs(:values_at).with(file_system_command).returns(@file_system_data)

          @profiler.get_file_systems

          assert_equal(@expected_data, @profiler.file_systems)
        end
      end

      context 'for hardware information' do
        setup do
          @cpu_arch_command = 'uname -m'
          @connector.stubs(:value_at).with(@cpu_arch_command).returns('x86_64')

          @memory_command = "cat /proc/meminfo | grep -i memtotal | awk '{print $2 / 1024}'"
          @connector.stubs(:value_at).with(@memory_command).returns('1024')
          
          @cpu_command = 'cat /proc/cpuinfo | egrep -i "processor|vendor|mhz|name|cores"'
          @cpu_data = %q{
            processor       : 0
            vendor_id       : AuthenticAMD
            model name      : AMD Opteron Processor 6174
            cpu MHz         : 2212.0
            cpu cores       : 2
            processor       : 1
            vendor_id       : AuthenticAMD
            model name      : AMD Opteron Processor 6174
            cpu MHz         : 2212.0
            cpu cores       : 2
          }.split(/\n/)
          @connector.stubs(:values_at).with(@cpu_command).returns(@cpu_data)
          
          @dmidecode_command = '/usr/bin/sudo /usr/sbin/dmidecode -t 0,1,4'
          @dmidecode_data = %q{
            Version: 6.0
            Manufacturer: VMware, Inc.
            Product Name: VMware Virtual Platform
            Serial Number: VMware-1234
            Manufacturer: AuthenticAMD
            Current Speed: 2200 MHz
          }.split(/\n/)
          @connector.stubs(:values_at).with(@dmidecode_command, true).returns(@dmidecode_data)

          @expected_data = {
            :cpu_architecture=>64,
            :cpu_core_count=>2,
            :cpu_model=>'AMD Opteron Processor 6174',
            :cpu_physical_count=>1,
            :cpu_speed_mhz=>2200,
            :cpu_vendor=>'AuthenticAMD',
            :firmware_version=>'6.0',
            :model=>'VMware Virtual Platform',
            :memory_installed_mb=>1024,
            :serial=>'VMware-1234',
            :vendor=>'VMware, Inc.'
          }
        end

        should 'return hardware information via #get_hardware' do
          @profiler.get_hardware
          assert_equal(@expected_data, @profiler.hardware)
        end
      end

      # OS SPECIFIC
      #context 'for hosted shares' do
      #end

      # OS SPECIFIC
      #context 'for installed applications' do
      #end

      # OS SPECIFIC
      #context 'for installed patches' do
      #end

      # OS SPECIFIC
      #context 'for installed services' do
      #end

      context 'for local users and groups' do
        setup do
          @user_data = [
            'root:x:0:0:Super-User:/root:/sbin/sh',
            'usera:x:2001:10:User A:/export/home/usera:/bin/bash',
            'userb:x:2001:10:User B:/export/home/userb:/bin/bash'
          ]
          @group_data = ['root::0:', 'staff::10:']
          @expected_data = [{:members=>['root'], :name=>'root'}, {:members=>['usera', 'userb'], :name=>'staff'}]
        end

        should 'return local user groups and accounts via #get_local_user_groups if the server is not a domain controller' do
          @connector.stubs(:values_at).with('cat /etc/passwd | grep -v "^#"').returns(@user_data)
          @connector.stubs(:values_at).with('cat /etc/group | grep -v "^#"').returns(@group_data)

          @profiler.get_local_user_groups

          assert_equal(@expected_data, @profiler.local_user_groups)
        end
      end

      context 'for network identification' do
        should 'return the hostname and domain via #get_network_id when hostname and domain are properly returned' do
          expected_data = {:domain=>'mydomain.com', :hostname=>'SERVER01'}
          @connector.stubs(:value_at).with('hostname').returns(expected_data[:hostname])
          @connector.stubs(:value_at).with('domainname').returns(expected_data[:domain])

          @profiler.get_network_id

          assert_equal(expected_data, @profiler.network_id)
        end

        should 'return the hostname and domain via #get_network_id when hostname and domain in a single string' do
          expected_data = {:domain=>'mydomain.com', :hostname=>'SERVER01'}
          @connector.stubs(:value_at).with('hostname').returns("#{expected_data[:hostname]}.#{expected_data[:domain]}")
          @connector.stubs(:value_at).with('domainname').returns(nil)

          @profiler.get_network_id
          
          assert_equal(expected_data, @profiler.network_id)
        end
      end

      context 'for network interfaces' do
        setup do
          @hardware_command = '/sbin/lspci -mmv | egrep -i "class:[[:space:]]*(ethernet controller|fibre channel)" -B1 -A5'
          @ethernet_mapping_command = %q{ls /sys/class/net | awk '{cmd="readlink -f /sys/class/net/" $1 "/device/"; cmd | getline link; print $1 "|" link}'}
          @link_properties_command = %q{find -L /sys/class/net/ -mindepth 2 -maxdepth 2 2>/dev/null | awk '{cmd = "cat " $0 " 2>/dev/null"; cmd | getline value; print $0 "|" value;}'}
          @ip_addr_command = %q{/sbin/ip addr | awk '{if($0 ~ /^[0-9]:/) {print "\n" $0} else {print $0}}'}

          @dns_server_command = "cat /etc/resolv.conf | grep ^nameserver | awk '{print $2}'"
          @dns_server_data = ['192.168.1.1', '192.168.1.2']
          @connector.stubs(:values_at).with(@dns_server_command).returns(@dns_server_data)

          @fibre_mapping_command = "find /sys/devices/pci* -regex '.*fc_host/host[0-9]'"
          @fibre_config_command = %q{find -L /sys/class/fc_host/ -mindepth 2 -maxdepth 2 | awk '{value=""; "cat " $1 " 2>/dev/null" | getline value; print $1 "|" value;}'}
        end

        should 'return ethernet interface information via #get_network_interfaces' do
          @expected_data = [
            @profiler.network_interface_template.merge({
              :current_speed_mbps=>1000,
              :dns_servers=>['192.168.1.1', '192.168.1.2'],
              :duplex=>'full',
              :ip_addresses=>[
                {:ip_address=>'192.168.1.3', :subnet=>'255.255.255.0'},
                {:ip_address=>'192.168.1.4', :subnet=>'255.255.255.0'},
              ],
              :mac_address=>'01:01:01:01:01:01',
              :model=>'VMXNET Ethernet Controller',
              :mtu=>1500,
              :name=>'eth0',
              :status=>'up',
              :type=>'ethernet',
              :vendor=>'VMware'
            }),
            @profiler.network_interface_template.merge({
              :dns_servers=>['192.168.1.1', '192.168.1.2'],
              :mac_address=>'01:01:01:01:01:01',
              :model=>'VMXNET Ethernet Controller',
              :name=>'eth1',
              :status=>'down',
              :type=>'ethernet',
              :vendor=>'VMware'
            })
          ]

          hardware_data = %q{
            Slot:   02:00.0
            Class:  Ethernet controller
            Vendor: VMware
            Device: VMXNET Ethernet Controller
            SVendor:        VMware
            SDevice:        VMXNET Ethernet Controller
            PhySlot:        32
            --
            Slot:   02:01.0
            Class:  Ethernet controller
            Vendor: VMware
            Device: VMXNET Ethernet Controller
            SVendor:        VMware
            SDevice:        VMXNET Ethernet Controller
            PhySlot:        33
          }.split(/\n/)
          @connector.stubs(:values_at).with(@hardware_command).returns(hardware_data)

          ethernet_mapping_data = [
            'eth0|/sys/devices/pci0000:00/0000:00:11.0/0000:02:00.0',
            'eth1|/sys/devices/pci0000:00/0000:00:11.0/0000:02:01.0'
          ]
          @connector.stubs(:values_at).with(@ethernet_mapping_command).returns(ethernet_mapping_data)

          link_properties = %q{
            /sys/class/net/eth0/address|01:01:01:01:01:01
            /sys/class/net/eth0/broadcast|ff:ff:ff:ff:ff:ff
            /sys/class/net/eth0/speed|1000
            /sys/class/net/eth0/duplex|full
            /sys/class/net/eth0/carrier|1
            /sys/class/net/eth0/mtu|1500
            /sys/class/net/eth1/address|01:01:01:01:01:01
            /sys/class/net/eth1/broadcast|ff:ff:ff:ff:ff:ff
            /sys/class/net/eth1/speed|
            /sys/class/net/eth1/duplex|full
            /sys/class/net/eth1/carrier|0
            /sys/class/net/eth1/mtu|1500
          }.split(/\n/)
          @connector.stubs(:values_at).with(@link_properties_command).returns(link_properties)

          ip_addr_data = %q{
            1: lo: <LOOPBACK,UP,LOWER_UP> mtu 16436 qdisc noqueue
              link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
              inet 127.0.0.1/8 scope host lo
              inet6 ::1/128 scope host
                valid_lft forever preferred_lft forever

            2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast qlen 1000
              link/ether 01:01:01:01:01:01 brd ff:ff:ff:ff:ff:ff
              inet 192.168.1.3/24 brd 192.168.1.255 scope global eth0
              inet 192.168.1.4/24 brd 192.168.1.255 scope global eth0:1
              inet6 fe80::250:56ff:fead:37/64 scope link
                valid_lft forever preferred_lft forever

            3: eth1: <BROADCAST,MULTICAST> mtu 1500 qdisc pfifo_fast state DOWN qlen 1000
              link/ether 01:01:01:01:01:01 brd ff:ff:ff:ff:ff:ff
          }.strip.split(/\n/)
          @connector.stubs(:values_at).with(@ip_addr_command).returns(ip_addr_data)

          @profiler.get_network_interfaces
          assert_equal(@expected_data, @profiler.network_interfaces)
        end

        should 'return fibre channel interface information via #get_network_interfaces' do
          @expected_data = [@profiler.network_interface_template.merge({
            :current_speed_mbps=>2000,
            :fabric_name=>'00000000aaaaaaaa',
            :model=>'ISP2312-based 2Gb Fibre Channel to PCI-X HBA',
            :name=>'host1',
            :node_wwn=>'00000000aaaaaaaa',
            :port_wwn=>'00000000aaaaaaaa',
            :status=>'up',
            :type=>'fibre',
            :vendor=>'QLogic Corp.'
          })]

          hardware_data = %q{
            Slot:   05:0d.0
            Class:  Fibre Channel
            Vendor: QLogic Corp.
            Device: ISP2312-based 2Gb Fibre Channel to PCI-X HBA
            SVendor:        QLogic Corp.
            SDevice:        Device 0149
            Rev:    02
          }.split(/\n/)
          @connector.stubs(:values_at).with(@hardware_command).returns(hardware_data)

          fibre_mapping_data = ['/sys/devices/pci0000:04/0000:04:09.0/0000:05:0d.0/host1/fc_host/host1']
          @connector.stubs(:values_at).with(@fibre_mapping_command).returns(fibre_mapping_data)

          fibre_config_data = %q{
            /sys/class/fc_host/host1/node_name|0x00000000aaaaaaaa
            /sys/class/fc_host/host1/port_name|0x00000000aaaaaaaa
            /sys/class/fc_host/host1/port_state|Online
            /sys/class/fc_host/host1/speed|2 Gbit
            /sys/class/fc_host/host1/fabric_name|0x00000000aaaaaaaa
          }.strip.split(/\n/)
          @connector.stubs(:values_at).with(@fibre_config_command).returns(fibre_config_data)

          @profiler.get_network_interfaces
          assert_equal(@expected_data, @profiler.network_interfaces)
        end
      end

      # OS SPECIFIC
      #context 'for operating system information' do
      #end

      context 'for running processes information' do
        setup do
          @now = 'Tue Apr 12 12:00:00 EDT 2013'
          @process_data = ['01:01:01 05:59:59 myscript -a']

          @expected_data = [{
            :command=>'myscript -a',
            :cpu_time=>'00-01:01:01',
            :date_started=>DateTime.parse('2013-04-12T06:00:01-04:00')
          }]
        end

        should 'return process information via #get_running_processes' do
          @connector.stubs(:value_at).with('date').returns(@now)
          @connector.stubs(:values_at).with('ps -eo time,etime,comm | tail -n +2 | grep -v defunct').returns(@process_data)

          @profiler.get_running_processes

          assert_equal(@expected_data, @profiler.running_processes)
        end
      end
    end
  end
end