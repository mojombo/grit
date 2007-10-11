module Grit
  
  class Git
    class << self
      attr_accessor :git_binary
    end
  
    self.git_binary = "/usr/bin/env git"
    
    attr_accessor :git_dir
    
    def initialize(git_dir)
      self.git_dir = git_dir
    end
    
    # Run the given git command with the specified arguments and return
    # the result as a chomped String
    #   +cmd+ is the command
    #   +args+ is the list of arguments (to be joined by spaces)
    #
    # Examples
    #   git.rev_list('--parents', '--header')
    #
    # Returns String
    def method_missing(cmd, *args)
      `#{Git.git_binary} --git-dir='#{self.git_dir}' #{cmd.to_s.gsub(/_/, '-')} #{args.join(' ')}`.chomp
    end
  end # Git
  
end # Grit