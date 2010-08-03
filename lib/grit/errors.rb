module Grit
  class InvalidGitRepositoryError < StandardError
  end

  class NoSuchPathError < StandardError
  end

  class InvalidObjectType < StandardError
  end
end
