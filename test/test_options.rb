require 'setup_tests'

class OptionsTest < Test::Unit::TestCase
  context 'the options for a Target' do
    setup do
      @options = Options.new
    end

    should 'be modifiable via the options hash' do
      @options[:auto_scrub_data] = false
      @options[:connection_types] = [:ssh, :wmi]
      @options[:credentials] = [{:user=>'someuser'}]
      @options[:log_level] = Logger::INFO
      @options[:profiles] = [:windows_core]
      @options[:snmp_options] = {:MibModules=>['IF-MIB']}
      @options[:ssh_options] = {:keys=>'~/.ssh/my_private_key', :verbose=>:debug}

      assert_equal(false, @options[:auto_scrub_data])
      assert_equal([:ssh, :wmi], @options[:connection_types])
      assert_equal([{:user=>'someuser'}], @options[:credentials])
      assert_equal(Logger::INFO, @options[:log_level])
      assert_equal([:windows_core], @options[:profiles])
      assert_equal({:MibModules=>['IF-MIB']}, @options[:snmp_options])
      assert_equal({:keys=>'~/.ssh/my_private_key', :verbose=>:debug}, @options[:ssh_options])
    end

    should 'error if invalid options are provided' do
      assert_raise(ArgumentError) {@options[:invalid_option] = nil}
    end

    should 'error if invalid options are passed to #add_credential' do
      assert_raise(ArgumentError) {@options.add_credential(:password=>'somepass')}
      assert_raise(ArgumentError) {@options.add_credential(:user=>'someuser', :connection_types=>[:i_dont_exist])}
      assert_raise(ArgumentError) {@options.add_credential([{:user=>'someuser1'},{:user=>'someuser2'}])}
    end

    should 'allow its credentials be added through #add_credential' do
      @options.add_credential(:user=>'someuser', :password=>'somepass', :connection_types=>[:wmi])
      @options.add_credential(:user=>'someotheruser', :connection_types=>[:ssh])
      assert_equal([
        {:user=>'someuser', :password=>'somepass', :connection_types=>[:wmi]},
        {:user=>'someotheruser', :connection_types=>[:ssh]}
      ], @options[:credentials])
    end
  end
end
