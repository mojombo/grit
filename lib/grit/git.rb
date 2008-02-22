module Grit
  
  class Git
    undef_method :clone
    
    class << self
      attr_accessor :git_binary
    end
  
    self.git_binary = "/usr/bin/env git"
    
    attr_accessor :git_dir
    
    def initialize(git_dir)
      self.git_dir = git_dir
    end
    
    # Run the given git command with the specified arguments and return
    # the result as a String
    #   +cmd+ is the command
    #   +options+ is a hash of Ruby style options
    #   +args+ is the list of arguments (to be joined by spaces)
    #
    # Examples
    #   git.rev_list({:max_count => 10, :header => true}, "master")
    #
    # Returns String
    def method_missing(cmd, options = {}, *args)
      opt_args = transform_options(options)
      ext_args = args.map { |a| a == '--' ? a : "'#{a}'" }
      
      call = "#{Git.git_binary} --git-dir='#{self.git_dir}' #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + ext_args).join(' ')}"
      puts call if Grit.debug
      response = `#{call}`
      puts response if Grit.debug
      response
    end
    
    # Transform Ruby style options into git command line options
    #   +options+ is a hash of Ruby style options
    #
    # Returns String[]
    #   e.g. ["--max-count=10", "--header"]
    def transform_options(options)
      args = []
      options.keys.each do |opt|
        if opt.to_s.size == 1
          if options[opt] == true
            args << "-#{opt}"
          else
            val = options.delete(opt)
            args << "-#{opt.to_s} '#{val}'"
          end
        else
          if options[opt] == true
            args << "--#{opt.to_s.gsub(/_/, '-')}"
          else
            val = options.delete(opt)
            args << "--#{opt.to_s.gsub(/_/, '-')}='#{val}'"
          end
        end
      end
      args
    end
  end # Git
  
end # Grit