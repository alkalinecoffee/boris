module Boris
  module Structure
    include Lumberjack
    
    CATEGORIES = %w{
      file_systems
      hardware
      hosted_shares
      installed_applications
      installed_patches
      installed_services
      local_user_groups
      network_id
      network_interfaces
      operating_system
      running_processes
    }

    CATEGORIES.each do |category|
      attr_accessor category.to_sym
    end
    
    def file_system_template
      [
        :capacity_mb,
        :file_system,
        :mount_point,
        :san_storage,
        :used_space_mb
      ].to_nil_hash
    end

    def hosted_share_template
      [
        :name,
        :path
      ].to_nil_hash
    end

    def installed_application_template
      [
        :date_installed,
        :install_location,
        :license_key,
        :name,
        :vendor,
        :version
      ].to_nil_hash
    end

    def installed_patch_template
      [
        :date_installed,
        :installed_by,
        :patch_code        
      ].to_nil_hash
    end

    def installed_service_template
      [
        :name,
        :install_location,
        :start_mode
      ].to_nil_hash
    end

    def local_user_groups_template
      {
        :group=>nil,
        :members=>[]
      }
    end

    def network_interface_template
      [
        :auto_negotiate,
        :current_speed_mbps,
        :duplex,
        :fabric_name,
        :is_uplink,
        :mac_address,
        :model,
        :model_id,
        :mtu,
        :name,
        :node_wwn,
        :port_wwn,
        :remote_mac_address,
        :remote_wwn,
        :status,
        :type,
        :vendor,
        :vendor_id,
        :dns_servers=>[],
        :ip_addresses=>[]
      ].to_nil_hash
    end

    def running_process_template
      [
        :command,
        :cpu_time,
        :date_started
      ].to_nil_hash
    end

    def get_file_systems
      debug 'preparing to fetch file systems'
      @file_systems = []
    end

    def get_hardware
      debug 'preparing to fetch hardware'
      @hardware = [
        :cpu_architecture,
        :cpu_core_count,
        :cpu_model,
        :cpu_physical_count,
        :cpu_speed_mhz,
        :cpu_vendor,
        :firmware_version,
        :model,
        :memory_installed_mb,
        :serial,
        :vendor
      ].to_nil_hash
    end

    def get_hosted_shares
      debug 'preparing to fetch hosted shares'
      @hosted_shares = []
    end

    def get_installed_applications
      debug 'preparing to fetch installed applications'
      @installed_applications = []
    end

    def get_installed_patches
      debug 'preparing to fetch installed patches'
      @installed_patches = []
    end

    def get_installed_services
      debug 'preparing to fetch installed_services'
      @installed_services = []
    end

    def get_local_user_groups
      debug 'preparing to fetch users and groups'
      @local_user_groups = []
    end

    def get_network_id
      debug 'preparing to fetch network id'
      @network_id = [
        :domain,
        :hostname
      ].to_nil_hash
    end

    def get_network_interfaces
      debug 'preparing to fetch network_interfaces'
      @network_interfaces = []
    end

    def get_operating_system
      debug 'preparing to fetch operating system'
      @operating_system = [
        :date_installed,
        :kernel,
        :license_key,
        :name,
        :service_pack,
        :version,
        :features=>[],
        :roles=>[]
      ].to_nil_hash
    end

    def get_running_processes
      debug 'preparing to fetch running_processes'
      @running_processes = []
    end

    alias get_installed_daemons get_installed_services
  end
end
