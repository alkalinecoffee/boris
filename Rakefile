require 'rake'
require 'rake/testtask'

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

require 'boris/version'

task :build do
  system 'gem build boris.gemspec'
end

task :install => :build do
  system "gem install boris-#{Boris::VERSION}.gem"
end

task :release => :build do
  system "git tag -a v#{Boris::VERSION} -m 'Pushed #{Boris::VERSION}'"
  system 'git push --tags'
  system "gem push boris-#{Boris::VERSION}.gem"
end

Rake::TestTask.new do |t|
  t.libs = ["test"]
  t.test_files = FileList['test/**/test*.rb']
end
