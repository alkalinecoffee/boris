$: << '.'

Dir.chdir(File.dirname(__FILE__)) do
  test_files = Dir['test_*.rb'] - [('test_all.rb')]
  test_files.concat(Dir['**/test_*.rb'])

  test_files.each { |file| require file }
end




# require 'boris/helpers/array'
# require 'boris/helpers/constants'
# require 'boris/helpers/hash'
# require 'boris/helpers/scrubber'
# require 'boris/helpers/string'

# require 'boris/errors'


# require 'boris/helpers/net_tools'

# require 'boris/connectors'

# require 'boris/profilers/linux/redhat'
# require 'boris/profilers/unix/solaris'
# require 'boris/profilers/windows/windows2003'
# require 'boris/profilers/windows/windows2008'
# require 'boris/profilers/windows/windows2012'




