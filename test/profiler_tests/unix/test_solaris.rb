require 'setup_tests'

class SolarisCoreTest < BaseTestSetup
  context 'a Solaris target' do
    setup do
      @connector = @target.connector = SSHConnector.new(@host, {})
      @target.stubs(:target_profiler).returns(Profilers::Solaris)
      @target.force_profiler_to(Profilers::Solaris)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with('uname').returns('SunOS')
    end

    should 'detect when a target should use the Solaris profile' do
      assert_equal(Profilers::Solaris, @target.profiler.class)
    end

    context 'being scanned' do
      setup do
        @showrev_command = 'showrev'
        @zoneadm_command = '/usr/sbin/zoneadm list'
      end

      # handled by UNIX core
      #context 'for file system information' do
      #end

      context 'for hardware information' do
        setup do
          @memory_command = "/usr/sbin/prtconf | egrep -i 'memory size' | awk '{print $3}'"
          @memory_data = '1024'
          @connector.stubs(:value_at).with(@memory_command).returns(@memory_data)

          @isainfo_command = "isainfo -v | egrep -i applications | awk '{print $1}'"
          @isainfo_data = ['64-bit', '32-bit']
          @connector.stubs(:values_at).with(@isainfo_command).returns(@isainfo_data)

          @sparc_model_command = '/usr/sbin/prtconf -b | grep banner-name'
          
          @cpu_command = %q{kstat -m cpu_info | nawk '{if(tolower($1)~/^(chip_id|core_id|clock_mhz|vendor_id|brand)/) {sub($1, $1"|"); print $0}}'}
          @smbios_command = "/usr/sbin/smbios -t SMB_TYPE_SYSTEM | egrep -i 'manufacturer|product|serial'"
          
          @sparc_firmware_command = %q{/usr/platform/`uname -m`/sbin/prtdiag -v | egrep -i "^obp" | awk '{print $2}'}
          @x86_firmware_command = '/usr/sbin/smbios -t SMB_TYPE_BIOS | grep -i "version string"'
          @connector.stubs(:value_at).with(@x86_firmware_command).returns('Version string: 6.0')
          @connector.stubs(:value_at).with(@sparc_firmware_command).returns('6.0')
        end

        context 'for an x86-based platform' do
          setup do
            @showrev_data = ['Application architecture: i386']
            @cpu_data = %q{
              brand|            Intel(r) Xeon(r) CPU X5680 @ 3.33GHz
              chip_id|          0
              clock_MHz|        3333
              core_id|          0
              vendor_id|        GenuineIntel
              brand|            Intel(r) Xeon(r) CPU X5680 @ 3.33GHz
              chip_id|          0
              clock_MHz|        3333
              core_id|          1
              vendor_id|        GenuineIntel
            }.strip.split(/\n/)
            @cpu_data += @cpu_data # add another instance of this cpu, to emulate a hyperthreaded cpu
            
            @expected_data = {
              :cpu_architecture=>64,
              :cpu_core_count=>2,
              :cpu_model=>'Intel(r) Xeon(r) CPU X5680 @ 3.33GHz',
              :cpu_physical_count=>1,
              :cpu_speed_mhz=>3333,
              :cpu_vendor=>'GenuineIntel',
              :firmware_version=>'6.0',
              :model=>'System x3650 M3 -[1234ABCD]-',
              :memory_installed_mb=>1024,
              :serial=>'ABCD1234',
              :vendor=>'IBM'
            }

            @connector.stubs(:values_at).with(@showrev_command).returns(@showrev_data)
            @connector.stubs(:values_at).with(@cpu_command).returns(@cpu_data)
          end

          context 'in the global zone' do
            should 'return hardware information via #get_hardware' do

              @smbios_data = %q{
                Manufacturer: IBM
                Product: System x3650 M3 -[1234ABCD]-
                Serial Number: ABCD1234
              }.strip.split(/\n/)
              @connector.stubs(:values_at).with(@smbios_command).returns(@smbios_data)

              @connector.stubs(:values_at).with(@zoneadm_command).returns('global')

              @profiler.get_hardware
              assert_equal(@expected_data, @profiler.hardware)
            end
          end
        end

        context 'for a SPARC-based platform' do
          setup do
            @showrev_data = ['Application architecture: sparc']
            @cpu_data = %q{
              brand|            SPARC64-VI
              chip_id|          0
              clock_MHz|        2400
              core_id|          0
              brand|            SPARC64-VI
              chip_id|          0
              clock_MHz|        2400
              core_id|          1
            }.strip.split(/\n/)

            @expected_data = {
              :cpu_architecture=>64,
              :cpu_core_count=>2,
              :cpu_model=>'SPARC64-VI',
              :cpu_physical_count=>1,
              :cpu_speed_mhz=>2400,
              :cpu_vendor=>VENDOR_ORACLE,
              :firmware_version=>'6.0',
              :model=>nil,
              :memory_installed_mb=>1024,
              :serial=>nil,
              :vendor=>VENDOR_ORACLE
            }

            @connector.stubs(:values_at).with(@showrev_command).returns(@showrev_data)
            @connector.stubs(:values_at).with(@cpu_command).returns(@cpu_data)
          end

          context 'in the global zone' do
            should 'return hardware information via #get_hardware' do
              @connector.stubs(:value_at).with(@sparc_model_command).returns('banner-name: Sun Fire 480R')

              @expected_data[:model] = 'Sun Fire 480R'

              @connector.stubs(:values_at).with(@zoneadm_command).returns('global')

              @profiler.get_hardware
              assert_equal(@expected_data, @profiler.hardware)
            end
          end

          context 'within a zone' do
            should 'return hardware information via #get_hardware' do
              @expected_data[:model] = 'Oracle Virtual Platform'
              @expected_data[:firmware_version] = nil

              @connector.stubs(:values_at).with(@smbios_command).returns([])
              @connector.stubs(:values_at).with(@zoneadm_command).returns('somezone')

              @profiler.get_hardware
              assert_equal(@expected_data, @profiler.hardware)
            end
          end
        end
      end

      context 'for hosted shares' do
        setup do
          @share_data = [
            '/export/someshare|/dev/vs/dsk/ADMINSHARE/vol_someshare',
            '/export/someothershare|/dev/vs/dsk/ADMINSHARE/vol_someothershare'
          ]

          @expected_data = [
            {:name=>@share_data[0].split('|')[0], :path=>@share_data[0].split('|')[1]},
            {:name=>@share_data[1].split('|')[0], :path=>@share_data[1].split('|')[1]}
          ]
        end

        should 'return hosted share information via #get_hosted_shares' do
          share_command = %q{nawk '{system("df -k | grep " $2)}' /usr/sbin/shares | nawk '{print $NF "|" $1}'}

          @connector.stubs(:values_at).with(share_command).returns(@share_data)

          @profiler.get_hosted_shares
          assert_equal(@expected_data, @profiler.hosted_shares)
        end
      end

      context 'for installed applications' do
        setup do
          @application_data = %q{
                NAME:  The Python interpreter, libraries and utilities
             VERSION:  2.3.3
            INSTDATE:  Jan 1 2013 00:00

                NAME:  The Python interpreter, libraries and utilities - development files
             VERSION:  2.3.3
             BASEDIR:  /usr
              VENDOR:  Oracle Corporation
            INSTDATE:  Jan 1 2013 00:00
            }.strip.split(/\n/)

          @expected_data = [
            {
              :date_installed=>DateTime.parse('Jan 1 2013 00:00'),
              :install_location=>nil,
              :license_key=>nil,
              :name=>'The Python interpreter, libraries and utilities',
              :vendor=>nil,
              :version=>'2.3.3'
            },
            {
              :date_installed=>DateTime.parse('Jan 1 2013 00:00'),
              :install_location=>'/usr',
              :license_key=>nil,
              :name=>'The Python interpreter, libraries and utilities - development files',
              :vendor=>'Oracle Corporation',
              :version=>'2.3.3'
            }
          ]
        end

        should 'return installed applications via #get_installed_applications' do
          application_command = "pkginfo -il -c application | egrep -i '^$|(name|version|basedir|vendor|instdate):'"

          @connector.stubs(:values_at).with(application_command).returns(@application_data)

          @profiler.get_installed_applications
          assert_equal(@expected_data, @profiler.installed_applications)
        end
      end

      context 'for installed patches' do
        setup do
          @patch_dir_data = '143506-01|Jan 1 00:00:00 2013'

          @patch_data = [
            '143506-01|SUNWPython-devel',
            '121671-01|SUNWPython'
          ]

          @expected_data = [
            {
              :date_installed=>DateTime.parse(@patch_dir_data.split('|')[1]),
              :installed_by=>nil,
              :patch_code=>@patch_dir_data.split('|')[0]
            },
          ]
        end

        should 'return installed patches via #get_installed_patches' do
          patch_dir_command = %q{ls -ego /var/sadm/patch | grep -v '^total' | nawk '{print $NF "|" $4 " " $5 " " $6 " " $7}'}

          @connector.stubs(:values_at).with(patch_dir_command).returns([@patch_dir_data])

          @profiler.get_installed_patches
          assert_equal(@expected_data, @profiler.installed_patches)
        end
      end

      context 'for installed services' do
        setup do
          @expected_data = [
            {:name=>'svc:/network/smtp:sendmail', :install_location=>nil, :start_mode=>nil},
            {:name=>'svc:/network/ftp:default', :install_location=>nil, :start_mode=>nil}
          ]
        end

        should 'return service information via #get_installed_services' do
          @connector.stubs(:values_at).with("svcs -a | nawk '{print $NF}'").returns(@expected_data.collect{|svc| svc[:name]})

          @profiler.get_installed_services
          assert_equal(@expected_data, @profiler.installed_services)
        end
      end

      # handled by UNIX core
      #context 'for local users and groups' do
      #end

      # handled by UNIX core
      #context 'for network identification' do
      #end

      context 'for network interfaces' do
        setup do

          @dns_server_command = "cat /etc/resolv.conf | grep ^nameserver | awk '{print $2}'"
          @dns_server_data = ['192.168.1.1', '192.168.1.2']
          @connector.stubs(:values_at).with(@dns_server_command).returns(@dns_server_data)

          @connector.stubs(:values_at).with(@showrev_command).returns(['Application architecture: sparc'])

          @kstat_command = %q{/usr/bin/kstat -c net -p | egrep "ifspeed|link_(up|duplex|autoneg)" | nawk '{print $1 "|" $2}' | egrep -v "aggr|lo|dman|sppp"}

          @prtpicl_ethernet_command = %q{/usr/sbin/prtpicl -c network -v | egrep ':model|:driver-name|:instance|:local-mac-address|:vendor-id|:device-id|\(network' | nawk '{if ($0 ~ /\(network/) print ""; else {first=$1; $1=""; print first "|" $0}}'}

          @fcinfo_command = %q{/usr/local/bin/sudo /usr/sbin/fcinfo hba-port | egrep -i "wwn|device name|model|manufacturer|driver name|state|current speed" | nawk '{$1=$1; if(tolower($1) ~ /^node/) print $0 "\n"; else print $0;}'}
          
          @mac_mapping_command = %q{/usr/bin/netstat -pn | grep SP | nawk '{print $1 "|" $2 "|" toupper($5)}'}
          
          @ifconfig_command = %q{/sbin/ifconfig -a | egrep 'flags|inet|zone' | nawk '{if($2~/^flags/ && $1!~/^(aggr|lo|dman|sppp)/) {current_line=$0; getline; {if($1!~/^zone/) {$1=$1; print current_line "\n" $0 "\n"}}}}'}
        end

        context 'in a standard three-interface setup' do
          setup do
            @connector.stubs(:values_at).with(@fcinfo_command).returns([])
            @connector.stubs(:values_at).with(@zoneadm_command).returns(['global'])

            @expected_ethernet_data = []

            # this interface is fully online... standard setup with multiple ipv4/ipv6 addresses
            @expected_ethernet_data << @profiler.network_interface_template.merge({
              :auto_negotiate=>false,
              :current_speed_mbps=>1000,
              :dns_servers=>['192.168.1.1', '192.168.1.2'],
              :duplex=>'full',
              :ip_addresses=>[
                {:ip_address=>'192.168.1.5', :subnet=>'255.255.255.0'},
                {:ip_address=>'fe80::a00::ffff:ffff:1000/10', :subnet=>nil}
              ],
              :mac_address=>'01:01:01:01:01:01',
              :model=>'Unknown Ethernet Adapter',
              :model_id=>'0x1234',
              :mtu=>1500,
              :name=>'e1000g0',
              :status=>'up',
              :type=>'ethernet',
              :vendor_id=>'0x1234'
            })

            # this interface has no physical connection but is configured to be up with ipv4 addresses...
            # should report status as down with no ip or link data
            @expected_ethernet_data << @profiler.network_interface_template.merge({
              :dns_servers=>['192.168.1.1', '192.168.1.2'],
              :mac_address=>'01:01:01:01:01:01',
              :model=>'Unknown Ethernet Adapter',
              :model_id=>'0x1234',
              :name=>'nxge0',
              :status=>'down',
              :type=>'ethernet',
              :vendor_id=>'0x1234'
            })

            # this port has a physical connection but is not configured for use...
            # should report status as down
            @expected_ethernet_data << @expected_ethernet_data[1].merge({:name=>'ce0'})
          end

          should 'return ethernet information for both interfaces via #get_network_interfaces' do
            @connector.stubs(:values_at).with(@prtpicl_fibre_command).returns([])

            prtpicl_ethernet_data = %q{
              :vendor-id|0x1234
              :device-id|0x1234
              :local-mac-address|01  01  01  01  01  01
              :instance|0
              :driver-name|e1000g

              :vendor-id|0x1234
              :device-id|0x1234
              :local-mac-address|01  01  01  01  01  01
              :instance|0
              :driver-name|nxge

              :vendor-id|0x1234
              :device-id|0x1234
              :local-mac-address|01  01  01  01  01  01
              :instance|0
              :driver-name|ce
            }.strip.split(/\n/)
            @connector.stubs(:values_at).with(@prtpicl_ethernet_command).returns(prtpicl_ethernet_data)

            ifconfig_data = %q{
              e1000g0: flags=123456<UP,BROADCAST,RUNNING,MULTICAST,DEPRECATED,IPv4,FIXEDMTU> mtu 1500 index 2
                inet 192.168.1.5 netmask ffffff00 broadcast 192.168.1.255

              e1000g0:1: flags=123456<UP,MULTICAST,IPv6> mtu 1500 index 2
                inet6 fe80::a00::ffff:ffff:1000/10

              nxge1: flags=123456<UP,BROADCAST,MULTICAST,IPv4> mtu 1500 index 3
                inet 192.168.1.6 netmask ffffff00 broadcast 192.168.1.255

              nxge1:1 flags=123456<UP,BROADCAST,RUNNING,MULTICAST,IPv4> mtu 1500 index 3
                inet 192.168.1.7
              }.strip.split(/\n/)
            @connector.stubs(:values_at).with(@ifconfig_command).returns(ifconfig_data)

            kstat_data = %q{
              e1000g:0:mac:ifspeed|1000000000
              e1000g:0:mac:link_autoneg|0
              e1000g:0:mac:link_duplex|2
              e1000g:0:mac:link_up|1
              nxge:0:mac:ifspeed|1000000000
              nxge:0:mac:link_autoneg|1
              nxge:0:mac:link_duplex|2
              nxge:0:mac:link_up|0
              ce:0:ce0:ifspeed|1000000000
              ce:0:mac:link_autoneg|1
              ce:0:mac:link_duplex|2
              ce:0:mac:link_up|1
            }.strip.split(/\n/)
            @connector.stubs(:values_at).with(@kstat_command).returns(kstat_data)

            mac_mapping_data = ['e1000g0|192.168.1.5|01:01:01:01:01:01', 'ce0|192.168.1.5|01:01:01:01:01:01']
            @connector.stubs(:values_at).with(@mac_mapping_command).returns(mac_mapping_data)

            @profiler.get_network_interfaces
            assert_equal(@expected_ethernet_data, @profiler.network_interfaces)
          end
        end

        context 'of a child zone' do
          setup do
            @connector.stubs(:values_at).with(@zoneadm_command).returns(['childzone'])

            @expected_ethernet_data = [@profiler.network_interface_template.merge({
              :current_speed_mbps=>1000,
              :dns_servers=>['192.168.1.1', '192.168.1.2'],
              :duplex=>'full',
              :ip_addresses=>[{:ip_address=>'192.168.1.2', :subnet=>'255.255.255.0'}],
              :mac_address=>'01:01:01:01:01:01',
              :model=>'Virtual Ethernet Adapter',
              :mtu=>1500,
              :name=>'ce1',
              :status=>'up',
              :type=>'ethernet',
              :vendor=>VENDOR_ORACLE
            })]
          end

          should 'return ethernet information for an interface on a zone via #get_network_interfaces' do
            @connector.stubs(:values_at).with(@fcinfo_command).returns([])

            # a child zone may show the interfaces of the host via kstat, but not via ifconfig,
            # so any active interfaces found in kstat should be ignored
            ifconfig_data = %q{
              ce1:1: flags=1000843<UP,BROADCAST,RUNNING,MULTICAST,IPv4> mtu 1500 index 3
                inet 192.168.1.2 netmask ffffff00 broadcast 192.168.1.1
            }.strip.split(/\n/)
            @connector.stubs(:values_at).with(@ifconfig_command).returns(ifconfig_data)

            kstat_data = %q{
              ce:1:ce1:ifspeed|1000000000
              ce:1:ce1:link_duplex|2
              ce:1:ce1:link_up|1
              e1000g:0:e1000g0:ifspeed|1000000000
              e1000g:0:mac:ifspeed|1000000000
              e1000g:0:mac:link_autoneg|1
              e1000g:0:mac:link_duplex|2
              e1000g:0:mac:link_up|1
            }.strip.split(/\n/)
            @connector.stubs(:values_at).with(@kstat_command).returns(kstat_data)

            mac_mapping_data = ['ce1|192.168.1.2|01:01:01:01:01:01']
            @connector.stubs(:values_at).with(@mac_mapping_command).returns(mac_mapping_data)

            @profiler.get_network_interfaces
            assert_equal(@expected_ethernet_data, @profiler.network_interfaces)
          end
        end

        context 'in a fibre channel setup' do
          setup do
            @expected_fibre_data = [@profiler.network_interface_template.merge({
              :current_speed_mbps=>4000,
              :model=>'375-2200-xx',
              :name=>'/dev/cfg/c1',
              :node_wwn=>'00000000aaaaaaaa',
              :port_wwn=>'00000000aaaaaaaa',
              :status=>'up',
              :type=>'fibre',
              :vendor=>'QLogic Corp.',
            })]

            @connector.stubs(:values_at).with(@kstat_command).returns([])
            @connector.stubs(:values_at).with(@mac_mapping_command).returns([])
            @connector.stubs(:values_at).with(@ifconfig_command).returns([])
            @connector.stubs(:values_at).with(@zoneadm_command).returns(['global'])
          end

          should 'return fibre interface information via #get_network_interfaces' do
            fcinfo_data = %q{
              HBA Port WWN: 00000000aaaaaaaa
              OS Device Name: /dev/cfg/c1
              Manufacturer: QLogic Corp.
              Model: 375-2200-xx
              Driver Name: qlc
              State: online
              Current Speed: 4Gb
              Node WWN: 00000000aaaaaaaa
            }.strip.split(/\n/)
            @connector.stubs(:values_at).with(@fcinfo_command).returns(fcinfo_data)

            @profiler.get_network_interfaces
            assert_equal(@expected_fibre_data, @profiler.network_interfaces)
          end
        end
      end

      context 'for operating system information' do
        setup do
          @os_data = '5.10 Generic_1234567-89'

          @expected_data = {
            :date_installed=>DateTime.parse('Jan 1 2013'),
            :features=>[],
            :kernel=>@os_data.split[1],
            :license_key=>nil,
            :name=>'Oracle Solaris',
            :roles=>[],
            :service_pack=>nil,
            :version=>@os_data.split[0].after_period
          }
        end

        should 'return operating system information via #get_operating_system' do
          @connector.stubs(:value_at).with(%q{ls -l /var/sadm/system/logs/install_log | nawk '{print $6" "$7" "$8'}}).returns('Jan 1 2013')
          @connector.stubs(:value_at).with('uname -rv').returns(@os_data)

          @profiler.get_operating_system
          assert_equal(@expected_data, @profiler.operating_system)
        end
      end
    end
  end
end