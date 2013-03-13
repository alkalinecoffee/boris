module Boris

  class ConnectionFailed < StandardError; end

  class ConnectionAlreadyActive < StandardError; end

  class InvalidCredentials < ConnectionFailed; end

  class InvalidOption < StandardError; end

  class InvalidTargetName < StandardError; end

  class MissingCredentials < Exception; end

  class NoActiveConnection < StandardError; end

  class NoProfilerDetected < StandardError; end

  class PasswordExpired < StandardError; end

end