class BorisLogger < Logger
  def initialize(output)
    super(output)

    self.datetime_format = '%m-%d-%Y %H:%M:%S'

    self.formatter = proc do |severity, time, progname, msg|
      sprintf("%-5s %-24s %-27s %-s\n", severity, time, progname, msg)
    end
  end
end

module Boris
  @@logger = BorisLogger.new(STDOUT)
  @@logger.level = Logger::FATAL

  # Allow all objects in Boris to have access to the logging mechanism. Any classes simply
  # need to include Lumberjack to have the ability to use the logger.
  def self.logger
    @@logger
  end

  # Sets the logging level for Boris. The setting here will carry down to all objects created
  # during this session.
  #
  #  Boris.log_level = :debug
  #
  # @param [Symbol] level a symbol for setting the log level
  #  # Options are: +:debug+, +:info+, +:warn+, +:error+, +:fatal+ (default)
  def self.log_level=(level)
    @@logger.level = case level
    when :debug then Logger::DEBUG
    when :info then Logger::INFO
    when :warn then Logger::WARN
    when :error then Logger::ERROR
    when :fatal then Logger::FATAL
    else raise ArgumentError, "invalid logger level specified (#{level.inspect})"
    end
  end

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

    private

    def append_target_name(msg)
      "#{@host}: #{msg}"
      #@host ? "#{@host}: #{msg}" : msg
    end

    def facility
      @facility ||= self.class.name.gsub(/::/, '.').gsub(/([a-z])([A-Z])/, "\\1_\\2").downcase
    end
  end
end
