Gem::Specification.new do |s|
  s.name              = 'boris'
  s.version           = '1.0.0'
  s.summary           = 'Boris: A network-scanning library.'
  s.description       = s.summary + ' Boris allows you to write programs for logging into and pulling information off of various server platforms and other types of networked devices.'

  s.author            = 'Joe Martin'
  s.email             = 'jm202@yahoo.com'
  s.homepage          = ''

  s.required_ruby_version = '>= 1.9.3'

  s.requirements      << 'netaddr'
  s.requirements      << 'net/ssh'
  s.requirements      << 'snmp'

  s.add_runtime_dependency 'netaddr'
  s.add_runtime_dependency 'net-ssh'
  s.add_runtime_dependency 'snmp'

  s.add_development_dependency 'mocha'
  s.add_development_dependency 'shoulda'

  s.require_paths     = %w[lib]

  s.files             = %w{
    boris.gemspec
    CHANGELOG.rdoc
    LICENSE
    Rakefile
    README
    lib/boris.rb
    lib/boris/connectors.rb
    lib/boris/errors.rb
    lib/boris/lumberjack.rb
    lib/boris/options.rb
    lib/boris/structure.rb
    lib/boris/target.rb
    lib/boris/connectors/snmp.rb
    lib/boris/connectors/ssh.rb
    lib/boris/connectors/wmi.rb
    lib/boris/helpers/array.rb
    lib/boris/helpers/hash.rb
    lib/boris/helpers/scrubber.rb
    lib/boris/helpers/string.rb
    lib/boris/profiles/linux_core.rb
    lib/boris/profiles/unix_core.rb
    lib/boris/profiles/windows_core.rb
    lib/boris/profiles/linux/redhat.rb
    lib/boris/profiles/unix/solaris.rb
    lib/boris/profiles/windows/win2003.rb
    lib/boris/profiles/windows/win2008.rb
    lib/boris/profiles/windows/win2012.rb
    test/setup_tests.rb
    test/test_all.rb
    test/test_options.rb
    test/test_profile.rb
    test/test_snmp.rb
    test/test_ssh.rb
    test/test_target.rb
    test/test_wmi.rb
    test/helper_tests/test_array.rb
    test/helper_tests/test_hash.rb
    test/helper_tests/test_string.rb
    test/profile_tests/test_linux_core.rb
    test/profile_tests/test_redhat.rb
    test/profile_tests/test_solaris.rb
    test/profile_tests/test_unix_core.rb
    test/profile_tests/test_windows.rb
  }

end