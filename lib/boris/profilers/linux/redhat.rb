require 'boris/profilers/linux_core'

module Boris; module Profilers
  class RedHat < Linux

    def get_file_systems; super; end
    def get_hardware; super; end
    def get_hosted_shares; super; end

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

      @installed_applications
    end

    def get_installed_patches; super; end

    def get_installed_services
      super
      service_data = @connector.values_at("/sbin/chkconfig --list | awk {'print $1'}")

      service_data.each do |service|
        h = installed_service_template
        h[:name] = service

        @installed_services << h
      end

      @installed_services
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
      @operating_system[:version] = os_base_name.extract(/linux (.+) release/i) + ' ' + os_data.grep(/^release/i)[0].after_colon

      @operating_system
    end
  end
end; end
