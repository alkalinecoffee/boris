require 'setup_tests'

class RedHatCoreTest < ProfileTestSetup
  context 'a RedHat target' do
    setup do
      @active_connection = @target.active_connection = instance_of(SSHConnector)

      @active_connection.stubs(:value_at).with(%q{ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb|system" | cut -d'/' -f3 | cut -d'-' -f1 | cut -d'_' -f1') =~ /redhat/i}).returns('redhat')
      @target.options[:profiles] = [Profiles::RedHat]
      @target.detect_profile
    end

    should 'detect when a target should use the Solaris profile' do
      assert_equal(Profiles::RedHat, @target.target_profile)
    end

    context 'being scanned' do
      setup do
      end

      # handled by linux core
      #context 'for file system information' do
      #end

      # handled by linux core
      #context 'for hardware information' do
      #end

      context 'for hosted shares' do
        # TODO add code for gathering list of hosted shares from redhat
      end

      context 'for installed applications' do
        setup do
          @application_data = [
            'zip|2.3.3|Red Hat, Inc.|x86_64|Tue 1 Jan 2013 00:00:00 AM EST',
            'zlib|2.3.3|Red Hat, Inc.|i386|Tue 1 Jan 2013 00:00:00 AM EST'
          ]

          @expected_data = [
            {
              :date_installed=>DateTime.parse('Tue 1 Jan 2013 00:00:00 AM EST'),
              :install_location=>nil,
              :license_key=>nil,
              :name=>'zip',
              :vendor=>'Red Hat, Inc.',
              :version=>'2.3.3'
            },
            {
              :date_installed=>DateTime.parse('Tue 1 Jan 2013 00:00:00 AM EST'),
              :install_location=>nil,
              :license_key=>nil,
              :name=>'zlib',
              :vendor=>'Red Hat, Inc.',
              :version=>'2.3.3'
            }
          ]
        end

        should 'return installed applications via #get_installed_applications' do
          application_command = "rpm -qa --queryformat '%{NAME}|%{VERSION}|%{VENDOR}|%{ARCH}|%{INSTALLTIME:date}\n' | sort"

          @active_connection.stubs(:values_at).with(application_command).returns(@application_data)

          @target.get_installed_applications
          assert_equal(@expected_data, @target.installed_applications)
        end
      end

      # n/a for linux
      #context 'for installed patches' do
      #end

      context 'for installed services' do
        setup do
          @expected_data = [
            {:name=>'sendmail', :install_location=>nil, :start_mode=>nil},
            {:name=>'smb', :install_location=>nil, :start_mode=>nil}
          ]
        end

        should 'return service information via #get_installed_services' do
          @active_connection.stubs(:values_at).with('/sbin/chkconfig --list').returns(@expected_data.collect{|svc| svc[:name]})

          @target.get_installed_services
          assert_equal(@expected_data, @target.installed_services)
        end
      end

      # handled by linux core
      #context 'for local users and groups' do
      #end

      # handled by linux core
      #context 'for network identification' do
      #end

      # handled by linux core
      #context 'for network interfaces' do
      #end

      context 'for operating system information' do
        setup do
          @kernel_data = '2.6.18-308.16.1.el5'
          @os_install_date = 'Tue 1 Jan 2013 00:00:00 AM EST'

          @os_data = [
            'Description:    Red Hat Enterprise Linux Server release 5.8 (Tikanga)',
            'Release:        5.8'
          ]

          @expected_data = {
            :date_installed=>DateTime.parse(@os_install_date),
            :features=>[],
            :kernel=>@kernel_data,
            :license_key=>nil,
            :name=>'Red Hat Enterprise Linux',
            :roles=>[],
            :service_pack=>nil,
            :version=>'Server 5.8'
          }
        end

        should 'return operating system information via #get_operating_system' do
          @active_connection.stubs(:value_at).with("rpm -qa basesystem --queryformat '%{INSTALLTIME:date}\n'").returns(@os_install_date)
          @active_connection.stubs(:value_at).with('uname -r').returns(@kernel_data)
          @active_connection.stubs(:values_at).with('lsb_release -a | egrep -i "description|release"').returns(@os_data)
          
          @target.get_operating_system
          assert_equal(@expected_data, @target.operating_system)
        end
      end
    end
  end
end