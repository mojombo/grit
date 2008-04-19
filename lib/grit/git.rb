trap("CHLD") do
  begin
    Process.wait(-1, Process::WNOHANG)
  rescue Object
  end
end

module Grit
  
  class Git
    
    include Grit::GitRuby
    
    class GitTimeout < RuntimeError
      attr_reader :command, :bytes_read

      def initialize(command = nil, bytes_read = nil)
        @command = command
        @bytes_read = bytes_read
      end
    end

    undef_method :clone
    
    class << self
      attr_accessor :git_binary, :git_timeout
    end
  
    self.git_binary  = "/usr/bin/env git"
    self.git_timeout = 5
    
    attr_accessor :git_dir, :bytes_read

    def initialize(git_dir)
      self.git_dir    = git_dir
      self.bytes_read = 0
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
      timeout  = options.delete(:timeout)
      timeout  = true if timeout.nil?

      opt_args = transform_options(options)
      ext_args = args.map { |a| a == '--' ? a : "'#{a}'" }
      
      call = "#{Git.git_binary} --git-dir='#{self.git_dir}' #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + ext_args).join(' ')}"
      puts call if Grit.debug
      response = timeout ? sh(call) : wild_sh(call)
      #puts response if Grit.debug
      response
    end

    
    
    def sh(command)
      pid, _, io, _ = Open4.popen4(command)
      ret = Timeout.timeout(self.class.git_timeout) { io.read }
      @bytes_read = 0
      @bytes_read += ret.size

      if @bytes_read > 5242880 # 5.megabytes
        bytes = @bytes_read
        @bytes_read = 0
        raise GitTimeout.new(command, bytes) 
      end

      ret
    rescue Object => e
      Process.kill('KILL', pid) rescue nil
      bytes = @bytes_read
      @bytes_read = 0
      raise GitTimeout.new(command, bytes)
    end

    def wild_sh(command)
      pid, _, io, _ = Open4.popen4(command)
      io.read
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
