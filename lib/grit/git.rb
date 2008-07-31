trap("CHLD") do
  begin
    Process.wait(-1, Process::WNOHANG)
  rescue Object
  end
end

module Grit
  
  class Git
    class GitTimeout < RuntimeError
      attr_reader :command, :bytes_read

      def initialize(command = nil, bytes_read = nil)
        @command = command
        @bytes_read = bytes_read
      end
    end

    undef_method :clone
    
    include GitRuby
    
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
      run('', cmd, '', options, args)
    end

    def run(prefix, cmd, postfix, options, args)
      timeout  = options.delete(:timeout)
      timeout  = true if timeout.nil?

      opt_args = transform_options(options)
      ext_args = args.map { |a| a == '--' ? a : "'#{a}'" }
      
      call = "#{prefix}#{Git.git_binary} --git-dir='#{self.git_dir}' #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + ext_args).join(' ')}#{postfix}"
      Grit.log(call) if Grit.debug
      response, err = timeout ? sh(call) : wild_sh(call)
      Grit.log(response) if Grit.debug
      Grit.log(err) if Grit.debug
      response
    end

    def sh(command)
      ret, pid, err = nil, nil, nil
      Open4.popen4(command) do |id, _, stdout, stderr|
        pid = id
        ret = Timeout.timeout(self.class.git_timeout) { stdout.read }
        err = stderr.read
        @bytes_read += ret.size

        if @bytes_read > 5242880 # 5.megabytes
          bytes = @bytes_read
          @bytes_read = 0
          raise GitTimeout.new(command, bytes) 
        end
      end
      [ret, err]
    rescue Errno::ECHILD
      [ret, err]
    rescue Object => e
      Process.kill('KILL', pid) rescue nil
      bytes = @bytes_read
      @bytes_read = 0
      raise GitTimeout.new(command, bytes)
    end

    def wild_sh(command)
      ret, err = nil, nil
      Open4.popen4(command) {|pid, _, stdout, stderr|
        ret = stdout.read
        err = stderr.read
      }
      [ret, err]
    rescue Errno::ECHILD
      [ret, err]
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
