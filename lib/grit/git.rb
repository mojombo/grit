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
    
    TRANSFORM = {:max_count => "--max-count=",
                 :skip => "--skip=",
                 :pretty => "--pretty=",
                 :sort => "--sort=",
                 :format => "--format="}
    
    # Run the given git command with the specified arguments and return
    # the result as a chomped String
    #   +cmd+ is the command
    #   +args+ is the list of arguments (to be joined by spaces)
    #
    # Examples
    #   git.rev_list('--parents', '--header')
    #
    # Returns String
    def method_missing(cmd, options, *args)
      opt_args = transform_options(options)
      
      `#{Git.git_binary} --git-dir='#{self.git_dir}' #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + args).join(' ')}`.chomp
    end
    
    def transform_options(options)
      args = []
      options.keys.each do |opt|
        if TRANSFORM[opt]
          if options[opt] == true
            args << TRANSFORM[opt]
          else
            val = options.delete(opt)
            args << TRANSFORM[opt] + val.to_s
          end
        end
      end
      args
    end
  end # Git
  
end # Grit