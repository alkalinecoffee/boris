class BorisLogger < Logger
  def initialize(output)
    super(output)

    self.datetime_format = '%m-%d-%Y %H:%M:%S'

    self.formatter = proc do |severity, time, progname, msg|
      sprintf("%-6s %-20s %-20s %-s\n", severity, time, progname, msg)
    end
  end
end

module Boris
  module Lumberjack
    attr_accessor :logger

    def debug(msg)
      logger.add(Logger::DEBUG, append_target_name(msg), facility) if logger && logger.debug?
    end

    def info(msg)
      logger.add(Logger::INFO, append_target_name(msg), facility) if logger && logger.info?
    end

    def warn(msg)
      logger.add(Logger::WARN, append_target_name(msg), facility) if logger && logger.warn?
    end

    def error(msg)
      logger.add(Logger::ERROR, append_target_name(msg), facility) if logger && logger.error?
    end

    def fatal(msg)
      logger.add(Logger::FATAL, append_target_name(msg), facility) if logger && logger.fatal?
    end

    # Options are: +:debug+, +:info+, +:warn+, +:error+, +:fatal+
    def log_level=(log_level)
      puts 'helloooooo'
      logger.level = case log_level
      when :debug then Logger::DEBUG
      when :info then Logger::INFO
      when :warn then Logger::WARN
      when :error then Logger::ERROR
      when :fatal then Logger::FATAL
      else raise ArgumentError, "invalid logger level specified (#{log_level.inspect})"
      end
    end

    private

    def append_target_name(msg)
      @host ? "#{@host}: #{msg}" : msg
    end

    def facility
      @facility ||= self.class.name.gsub(/::/, '.').gsub(/([a-z])([A-Z])/, "\\1_\\2").downcase
    end
  end
end
