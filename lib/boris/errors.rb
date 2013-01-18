module Boris
  class MissingCredentials < Exception; end

  class ConnectionFailed < StandardError; end

  class ConnectionAlreadyActive < StandardError; end

  class NoActiveConnection < StandardError; end

  class InvalidOption < StandardError; end

  class InvalidCredentials < ConnectionFailed; end

  class InvalidTargetName < StandardError; end
end