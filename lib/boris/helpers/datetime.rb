class DateTime

  # Returns a new DateTime object showing the exact date and time that
  # something occurred by using the difference in time between a date
  # and the time that has elapsed. This is used to calculate the exact
  # date and time that something occurred when we only know the current
  # time and the time that elapsed since that event occurred.
  #
  # For example, in UNIX, we can't easily determine when a process was
  # kicked off (by using data from the 'ps' command).  But the 'ps' command
  # will show us the time elapsed, so coupling that data with the current time,
  # we can figure out when that process was started.
  #
  #  now = DateTime.parse('2013-04-12T12:00:00-04:00')
  #  process_run_time = '1-05:59:59'
  #  DateTime.parse_start_date(now, process_run_time) #=> #<DateTime: 2013-04-11T10:00:01-04:00>
  #
  # @param base_time the base DateTime to calculate from (typically the current time)
  # @param time_elapsed String showing the time elapsed (format: %d-%H:%M:%S)
  # @return [DateTime] a new DateTime object showing the start date/time
  def self.parse_start_date(base_time, time_elapsed)
    time_elapsed = "0-#{time_elapsed}" unless time_elapsed =~ /-/

    time_elapsed = time_elapsed.split('-')
    days_back = time_elapsed[0].to_i
    time_elapsed = time_elapsed[1].split(':')
        
    hours_since = time_elapsed[0].to_i
    minutes_since = time_elapsed[1].to_i
    seconds_since = time_elapsed[2].to_i

    seconds_since += minutes_since * 60
    seconds_since += hours_since * 60 * 60
    seconds_since += days_back * 60 * 60 * 24
    
    started_on = (base_time.to_time - seconds_since).to_datetime
  end
end