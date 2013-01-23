Gem::Specification.new do |s|
  s.name              = 'boris'
  s.version           = '1.0.0'
  s.summary           = 'Boris: A networked-device scanning library.'
  s.description       = s.summary + ' Boris allows you to write programs for logging into and pulling information off of various server platforms, appliances, and other types of networked devices, producing clean and consistent data ideal for configuration managment usage.'

  s.author            = 'Joe Martin'
  s.email             = 'sharkwavemedia@gmail.com'
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

  s.files             = Dir.glob("{.,bin,lib}/**/*")

end
