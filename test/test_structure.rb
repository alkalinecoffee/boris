require 'setup_tests'

class ProfileStructure
  include Profiles::Structure
  attr_accessor :logger, :options
end

class StructureTest < Test::Unit::TestCase
  context 'a data structure' do
    setup do
      @structure = ProfileStructure.new
      @structure.options = Options.new
    end

    should 'provide us with a file system template via #file_system_template' do
      expected = [
        :capacity_mb,
        :file_system,
        :mount_point,
        :san_storage,
        :used_space_mb
      ].to_nil_hash

      assert_equal(expected, @structure.file_system_template)
    end

    should 'provide us with a hardware template via #get_hardware' do
      expected = [
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

      assert_equal(expected, @structure.get_hardware)
    end

    should 'provide us with an installed application template via #installed_application_template' do
      expected = [
        :date_installed,
        :install_location,
        :license_key,
        :name,
        :vendor,
        :version
      ].to_nil_hash

      assert_equal(expected, @structure.installed_application_template)
    end

    should 'provide us with a local user groups template via #local_user_groups_template' do
      expected = {
        :group=>nil,
        :members=>[]
      }
      
      assert_equal(expected, @structure.local_user_groups_template)
    end

    should 'provide us with a network identification template via #get_network_id' do
      expected = [
        :domain,
        :hostname
      ].to_nil_hash

      assert_equal(expected, @structure.get_network_id)
    end

    should 'provide us with a network interface template via #network_interface_template' do
      expected = [
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
      
      assert_equal(expected, @structure.network_interface_template)
    end

    should 'provide us with an operating system template via #get_operating_system' do
      expected = [
        :date_installed,
        :kernel,
        :license_key,
        :name,
        :service_pack,
        :version,
        :features=>[],
        :roles=>[]
      ].to_nil_hash
      
      assert_equal(expected, @structure.get_operating_system)
    end

    should 'provide us with a patch template via #installed_patch_template' do
      expected = [
        :date_installed,
        :installed_by,
        :patch_code        
      ].to_nil_hash

      assert_equal(expected, @structure.installed_patch_template)
    end

    should 'provide us with a share template via #hosted_share_template' do
      expected = [
        :name,
        :path
      ].to_nil_hash

      assert_equal(expected, @structure.hosted_share_template)
    end
  end
end