lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'boris/version'

Gem::Specification.new do |s|
  s.name              = 'boris'
  s.version           = Boris::VERSION
  s.summary           = 'Boris: A networked-device scanning library.'
  s.description       = s.summary + ' Boris allows you to write programs for logging into and pulling information off of various server platforms, appliances, and other types of networked devices, producing clean and consistent data ideal for configuration managment usage.'

  s.author            = 'Joe Martin'
  s.email             = 'jwmartin83@gmail.com'
  s.homepage          = 'https://github.com/alkalinecoffee/boris'

  s.required_ruby_version = '>= 1.9.3'

  s.add_dependency 'netaddr', '>= 1.5.0'
  s.add_dependency 'net-ssh', '>= 2.5.2'
  s.add_dependency 'snmp', '>= 1.1.0'

  s.add_development_dependency 'mocha', '>= 0.12.3'
  s.add_development_dependency 'shoulda', '>= 3.1.1'

  s.require_paths     = %w[lib]

  s.files             = Dir.glob("lib/**/*") + %w(CHANGELOG.md LICENSE.md Rakefile README.md)

end
