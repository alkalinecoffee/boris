$: << '.'

Dir.chdir(File.dirname(__FILE__)) do
  test_files = Dir['test_*.rb'] - [('test_all.rb')]
  test_files.concat(Dir['**/test_*.rb'])

  test_files.each { |file| require file }
end
