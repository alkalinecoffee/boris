require 'boris/profiles/linux_core'

module Boris; module Profiles
    module RedHat
      include Linux

      def self.connection_type
        Linux.connection_type
      end

      def self.matches_target?(connector)
        release_data = connector.values_at(%q{ls -d /etc/[A-Za-z]*[_-][rv]e[lr]* | grep -v "lsb|system" | cut -d '/' -f3 | cut -d '-' -f1 | cut -d '_' -f1}).join(' ')
        return true if release_data =~ /redhat/i
      end

      def get_file_systems; super; end
      def get_hardware; super; end

      def get_hosted_shares
        super

        # TODO add code for gathering list of hosted shares from redhat
      end

      def get_installed_applications
        super
        
        application_data = @connector.values_at('rpm -qa --queryformat "%{NAME}|%{VERSION}|%{VENDOR}|%{ARCH}|%{INSTALLTIME:date}\n" | sort')

        application_data.each do |application|
          application = application.split('|')
          h = installed_application_template

          h[:date_installed] = DateTime.parse(application[4])
          h[:install_location] = nil
          h[:name] = application[0]
          h[:vendor] = application[2]
          h[:version] = application[1]

          @installed_applications << h
        end
      end

      def get_installed_patches; super; end

      def get_installed_services
        super
        service_data = @connector.values_at('/sbin/chkconfig --list')

        service_data.each do |service|
          h = installed_service_template
          h[:name] = service

          @installed_services << h
        end
      end

      def get_local_user_groups; super; end
      def get_network_id; super; end
      def get_network_interfaces; super; end

      def get_operating_system
        super

        os_install_date = @connector.value_at("rpm -qa basesystem --queryformat '%{INSTALLTIME:date}\n'")
        kernel_version = @connector.value_at('uname -r')
        os_data = @connector.values_at('lsb_release -a | egrep -i "description|release"')

        @operating_system[:date_installed] = DateTime.parse(os_install_date)
        @operating_system[:kernel] = kernel_version

        os_base_name = os_data.grep(/^description/i)[0].after_colon
        @operating_system[:name] = os_base_name.split(/ linux /i)[0] + ' Linux'
        @operating_system[:version] = os_base_name.scan(/linux (.*) release/i).join + ' ' + os_data.grep(/^release/i)[0].after_colon
      end
    end
end; end
