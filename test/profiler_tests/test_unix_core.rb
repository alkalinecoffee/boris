require 'setup_tests'

class UNIXCoreTest < ProfilerTestSetup
  context 'a UNIX target' do
    setup do
      @connector = @target.connector = instance_of(SSHConnector)
      @target.stubs(:target_profiler).returns(Profilers::UNIX)
      @target.force_profiler_to(Profilers::UNIX)
      @profiler = @target.profiler
      @connector.stubs(:value_at).with('uname -a').returns('some_flavor_of_unix')
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
          file_system_command = %q{df -kl 2>/dev/null | grep ^/ | nawk '{print $1 "|" $2 / 1024 "|" $3 / 1024 "|" $6}'}

          @connector.stubs(:values_at).with(file_system_command).returns(@file_system_data)

          @profiler.get_file_systems

          assert_equal(@expected_data, @profiler.file_systems)
        end
      end

      # OS SPECIFIC
      #context 'for hardware information' do
      #end

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
            'usera:x:2001:10:User A:/export/home/usera:/bin/ksh',
            'userb:x:2001:10:User B:/export/home/userb:/bin/ksh'
          ]
          @group_data = ['root::0:', 'staff::10:']
          @expected_data = [{:members=>['root'], :name=>'root'}, {:members=>['usera', 'userb'], :name=>'staff'}]
        end

        should 'return local user groups and accounts via #get_local_user_groups' do
          @connector.stubs(:values_at).with('cat /etc/passwd | grep -v "^#"').returns(@user_data)
          @connector.stubs(:values_at).with('cat /etc/group | grep -v "^#"').returns(@group_data)

          @profiler.get_local_user_groups

          assert_equal(@expected_data, @profiler.local_user_groups)
        end
      end

      context 'for network identification' do
        setup do
          @expected_data = {:domain=>'mydomain.com', :hostname=>'SERVER01'}
        end

        should 'return the domain and hostname via #get_network_id' do
          @connector.stubs(:value_at).with('hostname').returns(@expected_data[:hostname])
          @connector.stubs(:value_at).with('domainname').returns(@expected_data[:domain])

          @profiler.get_network_id

          assert_equal(@expected_data, @profiler.network_id)
        end
      end

      # OS SPECIFIC
      #context 'for network interfaces' do; end
      #end

      # OS SPECIFIC
      #context 'for operating system information' do
      #end
    end
  end
end