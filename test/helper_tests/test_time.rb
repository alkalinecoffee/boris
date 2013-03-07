require 'setup_tests'

class TimeTest < Test::Unit::TestCase
  context 'the Time class' do
    should 'return the time for a windows filetime value presented in hex format' do
      assert_equal(DateTime.parse('2012-10-03 20:20:51 -0400').to_time, Time.filetime_to_time("01cda19c33ca01ce".hex))
    end
  end
end