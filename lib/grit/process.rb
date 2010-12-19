module Grit
  # Grit::Process includes logic for executing child processes and
  # reading/writing from their standard input, output, and error streams.
  #
  # Create an run a process to completion:
  #
  #   >> process = Grit::Process.new(['git', '--help'])
  #
  # Retrieve stdout or stderr output:
  #
  #   >> process.out
  #   => "usage: git [--version] [--exec-path[=GIT_EXEC_PATH]]\n ..."
  #   >> process.err
  #   => ""
  #
  # Check process exit status information:
  #
  #   >> process.status
  #   => #<Process::Status: pid=80718,exited(0)>
  #
  # Grit::Process is designed to take all input in a single string and
  # provides all output as single strings. It is therefore not well suited
  # to streaming large quantities of data in and out of commands.
  #
  # Q: Why not use popen3 or hand-roll fork/exec code?
  #
  # - It's more efficient than popen3 and provides meaningful process
  #   hierarchies because it performs a single fork/exec. (popen3 double forks
  #   to avoid needing to collect the exit status and also calls
  #   Process::detach which creates a Ruby Thread!!!!).
  #
  # - It's more portable than hand rolled pipe, fork, exec code because
  #   fork(2) and exec(2) aren't available on all platforms. In those cases,
  #   Grit::Process falls back to using whatever janky substitutes the platform
  #   provides.
  #
  # - It handles all max pipe buffer hang cases, which is non trivial to
  #   implement correctly and must be accounted for with either popen3 or
  #   hand rolled fork/exec code.
  class Process
    # Create and execute a new process.
    #
    # argv    - Array of [command, arg1, ...] strings to use as the new
    #           process's argv. When argv is a String, the shell is used
    #           to interpret the command.
    # env     - The new process's environment variables. This is merged with
    #           the current environment as if by ENV.merge(env).
    # options - Additional options:
    #           :input => str to write str to the process's stdin.
    #           :chdir => str to start the process in different working dir.
    #
    # Returns a new Process instance that has already executed to completion.
    # The out, err, and status attributes are immediately available.
    def initialize(argv, env={}, options={})
      @argv = argv
      @env = env
      @options = options.dup
      @options.delete(:chdir) if @options[:chdir].nil?
      @input = @options.delete(:input)
      exec!
    end

    # All data written to the child process's stdout stream as a String.
    attr_reader :out

    # All data written to the child process's stderr stream as a String.
    attr_reader :err

    # A Process::Status object with information on how the child exited.
    attr_reader :status

    # Determine if the process did exit with a zero exit status.
    def success?
      @status && @status.success?
    end

  private
    # Execute command, write input, and read output. This is called
    # immediately when a new instance of this object is initialized.
    def exec!
      # when argv is a string, use /bin/sh to interpret command
      argv = @argv
      argv = ['/bin/sh', '-c', argv.to_str] if argv.respond_to?(:to_str)

      # create some pipes (see pipe(2) manual -- the ruby docs suck)
      ird, iwr = IO.pipe
      ord, owr = IO.pipe
      erd, ewr = IO.pipe

      # spawn the child process with either end of pipes hooked together
      opts =
        @options.merge(
          # redirect fds        # close other sides
          :in  => ird,          iwr  => :close,
          :out => owr,          ord  => :close,
          :err => ewr,          erd  => :close
        )
      pid = spawn(@env, *(argv + [opts]))

      # we're in the parent, close child-side fds
      [ird, owr, ewr].each { |fd| fd.close }

      @out, @err = read_and_write(@input, iwr, ord, erd)

      ::Process.waitpid(pid)
      @status = $?
    rescue Object => boom
      [ird, iwr, ord, owr, erd, ewr].each { |fd| fd.close rescue nil }
      if @status.nil?
        ::Process.kill(pid) rescue nil
        (@status = ::Process.waitpid(pid)) rescue nil
      end
      raise
    end

    # maximum size
    BUFSIZE = (32 * 1024)

    # Start a select loop writing any input on the child's stdin and reading
    # any output from the child's stdout or stderr
    def read_and_write(input, stdin, stdout, stderr)
      input ||= ''
      out, err = '', ''
      offset = 0
      writers = [stdin]
      readers = [stdout, stderr]
      while ready = IO.select(readers, writers, readers + writers)
        boom = nil
        # write to stdin stream
        ready[1].each do |fd|
          begin
            size = fd.write_nonblock(input)
            input = input[size, input.size]
          rescue Errno::EPIPE => boom
          rescue Errno::EAGAIN, Errno::EINTR
          end
          if boom || input.size == 0
            stdin.close
            writers.delete(stdin)
          end
        end
        # read from stdout and stderr streams
        ready[0].each do |fd|
          buf = (fd == stdout) ? out : err
          begin
            buf << fd.readpartial(BUFSIZE)
          rescue Errno::EAGAIN, Errno::EINTR
          rescue EOFError
            readers.delete(fd)
            fd.close
          end
        end
        break if readers.empty? && writers.empty?
      end
      [out, err]
    end

    # Spawn a child process, perform IO redirection and environment prep, and
    # return the running process's pid.
    #
    # This method implements a limited subset of Ruby 1.9's Process::spawn.
    # The idea is that we can just use that when available, since most platforms
    # will eventually build in special (and hopefully good) support for it.
    #
    #   env     - Hash of { name => val } environment variables set in the child
    #             process.
    #   argv    - New process's argv as an Array. When this value is a string,
    #             the command may be run through the system /bin/sh or
    #   options - Supports a subset of Process::spawn options, including:
    #             :chdir => str to change the directory to str in the child
    #                 FD => :close to close a file descriptor in the child
    #                :in => FD to redirect child's stdin to FD
    #               :out => FD to redirect child's stdout to FD
    #               :err => FD to redirect child's stderr to FD
    #
    # Returns the pid of the new process as an integer. The process exit status
    # must be obtained using Process::waitpid.
    def spawn(env, *argv)
      options = (argv.pop if argv[-1].kind_of?(Hash)) || {}
      fork do
        # { fd => :close } in options means close that fd
        options.each { |k,v| k.close if v == :close && !k.closed? }

        # reopen stdin, stdout, and stderr on provided fds
        STDIN.reopen(options[:in])
        STDOUT.reopen(options[:out])
        STDERR.reopen(options[:err])

        # setup child environment
        env.each { |k, v| ENV[k] = v }

        # { :chdir => '/' } in options means change into that dir
        ::Dir.chdir(options[:chdir]) if options[:chdir]

        # do the deed
        ::Kernel::exec(*argv)
        exit! 1
      end
    end
  end
end
