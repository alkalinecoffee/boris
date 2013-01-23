module Boris; module Profiles
  module Structure
    include Lumberjack

    attr_accessor :file_systems
    attr_accessor :hardware
    attr_accessor :hosted_shares
    attr_accessor :installed_applications
    attr_accessor :installed_patches
    attr_accessor :installed_services
    attr_accessor :local_user_groups
    attr_accessor :network_id
    attr_accessor :network_interfaces
    attr_accessor :operating_system

    def self.matches_target?
      # insert code here to emphatically determine whether this profile
      # is suitable for using against the target

      # always return false for the core module... this method should never be
      # called by user code and kept here simply for consistency
      false
    end

    def retrieve_all
      debug "retrieving all configuration items"

      get_file_systems
      get_hardware
      get_hosted_shares
      get_installed_applications
      get_local_user_groups
      get_installed_patches
      get_installed_services
      get_network_id
      get_network_interfaces
      get_operating_system

      scrub_data! if @options[:auto_scrub_data]
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
        :status,
        :type,
        :vendor,
        :vendor_id,
        :dns_servers=>[],
        :ip_addresses=>[]
      ].to_nil_hash
    end

    def get_file_systems
      @file_systems = []
    end

    def get_hardware
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
      @hosted_shares = []
    end

    def get_installed_applications
      @installed_applications = []
    end

    def get_installed_patches
      @installed_patches = []
    end

    def get_installed_services
      @installed_services = []
    end

    def get_local_user_groups
      @local_user_groups = []
    end

    def get_network_id
      @network_id = [
        :domain,
        :hostname
      ].to_nil_hash
    end

    def get_network_interfaces
      @network_interfaces = []
    end

    def get_operating_system
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

    alias get_installed_daemons get_installed_services
  end
end; end