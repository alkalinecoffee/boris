class Time
  def self.filetime_to_time(filetime)
    Time.at((filetime - 116444556000000000) / 10000000)
  end
end