require 'setup_tests'

class DateTimeTest < Test::Unit::TestCase
  context 'the DateTime class' do
    should 'return a new DateTime object showing the start date via #parse_start_date' do

      now = DateTime.parse('2013-04-12T12:00:00-04:00')

      expected_dates = [
        {:expected_date=>DateTime.parse('2013-04-11T06:00:01-04:00'), :time_elapsed=>'1-05:59:59'},
        {:expected_date=>DateTime.parse('2013-04-12T06:00:01-04:00'), :time_elapsed=>'05:59:59'}
      ]
      
      expected_dates.each do |date|
        assert_equal(date[:expected_date], DateTime.parse_start_date(now, date[:time_elapsed]))
      end
    end
  end
end