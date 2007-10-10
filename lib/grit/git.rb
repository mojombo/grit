module Grit
  
  class Git
    class << self
      attr_accessor :git_binary
    end
  
    self.git_binary = "/usr/bin/env git"
    
    # Run the given git command with the specified arguments and return
    # the result as a chomped String
    #   +cmd+ is the command
    #   +args+ is the list of arguments (to be joined by spaces)
    #
    # Examples
    #   Grit::Git.rev_list('--parents', '--history')
    #
    # Returns String
    def self.method_missing(cmd, *args)
      `#{Git.git_binary} #{cmd.to_s.gsub(/_/, '-')} #{args.join(' ')}`.chomp
    end
  end # Git
  
end # Grit