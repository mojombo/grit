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
    #             :input   => str to write str to the process's stdin.
    #             :timeout => int number of seconds before we given up.
    #             :max     => total number of output bytes
    #           A subset of Process:spawn options are also supported on all
    #           platforms:
    #             :chdir => str to start the process in different working dir.
    #
    # Returns a new Process instance that has already executed to completion.
    # The out, err, and status attributes are immediately available.
    def initialize(argv, env={}, options={})
      @argv = argv
      @env = env

      @options = options.dup
      @input = @options.delete(:input)
      @timeout = @options.delete(:timeout)
      @max = @options.delete(:max)
      @options.delete(:chdir) if @options[:chdir].nil?

      exec!
    end

    # All data written to the child process's stdout stream as a String.
    attr_reader :out

    # All data written to the child process's stderr stream as a String.
    attr_reader :err

    # A Process::Status object with information on how the child exited.
    attr_reader :status

    # Total command execution time (wall-clock time)
    attr_reader :runtime

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

      # spawn the process and hook up the pipes
      pid, stdin, stdout, stderr = popen4(@env, *(argv + [@options]))

      # async read from all streams into buffers
      @out, @err = read_and_write(@input, stdin, stdout, stderr, @timeout, @max)

      # grab exit status
      @status = waitpid(pid)
    rescue Object => boom
      [stdin, stdout, stderr].each { |fd| fd.close rescue nil }
      if @status.nil?
        ::Process.kill('TERM', pid) rescue nil
        @status = waitpid(pid)      rescue nil
      end
      raise
    end

    # Exception raised when the total number of bytes output on the command's
    # stderr and stdout streams exceeds the maximum output size (:max option).
    class MaximumOutputExceeded < StandardError
    end

    # Exception raised when timeout is exceeded.
    class TimeoutExceeded < StandardError
    end

    # Maximum buffer size for reading
    BUFSIZE = (32 * 1024)

    # Start a select loop writing any input on the child's stdin and reading
    # any output from the child's stdout or stderr.
    #
    # input   - String input to write on stdin. May be nil.
    # stdin   - The write side IO object for the child's stdin stream.
    # stdout  - The read side IO object for the child's stdout stream.
    # stderr  - The read side IO object for the child's stderr stream.
    # timeout - An optional Numeric specifying the total number of seconds
    #           the read/write operations should occur for.
    #
    # Returns an [out, err] tuple where both elements are strings with all
    #   data written to the stdout and stderr streams, respectively.
    # Raises TimeoutExceeded when all data has not been read / written within
    #   the duration specified in the timeout argument.
    # Raises MaximumOutputExceeded when the total number of bytes output
    #   exceeds the amount specified by the max argument.
    def read_and_write(input, stdin, stdout, stderr, timeout=nil, max=nil)
      input ||= ''
      max = nil if max && max <= 0
      out, err = '', ''
      offset = 0

      timeout = nil if timeout && timeout <= 0.0
      @runtime = 0.0
      start = Time.now

      writers = [stdin]
      readers = [stdout, stderr]
      t = timeout
      while readers.any? || writers.any?
        ready = IO.select(readers, writers, readers + writers, t)
        raise TimeoutExceeded if ready.nil?

        # write to stdin stream
        ready[1].each do |fd|
          begin
            boom = nil
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

        # keep tabs on the total amount of time we've spent here
        @runtime = Time.now - start
        if timeout
          t = timeout - @runtime
          raise TimeoutExceeded if t < 0.0
        end

        # maybe we've hit our max output
        if max && ready[0].any? && (out.size + err.size) > max
          raise MaximumOutputExceeded
        end
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

    # Start a process with spawn options and return
    # popen4([env], command, arg1, arg2, [opt])
    #
    #   env     - The child process's environment as a Hash.
    #   command - The command and zero or more arguments.
    #   options - An options hash.
    #
    # See Ruby 1.9 IO.popen and Process::spawn docs for more info:
    # http://www.ruby-doc.org/core-1.9/classes/IO.html#M001640
    #
    # Returns a [pid, stdin, stderr, stdout] tuple where pid is the child
    # process's pid, stdin is a writeable IO object, and stdout + stderr are
    # readable IO objects.
    def popen4(*argv)
      # create some pipes (see pipe(2) manual -- the ruby docs suck)
      ird, iwr = IO.pipe
      ord, owr = IO.pipe
      erd, ewr = IO.pipe

      # spawn the child process with either end of pipes hooked together
      opts =
        ((argv.pop if argv[-1].is_a?(Hash)) || {}).merge(
          # redirect fds        # close other sides
          :in  => ird,          iwr  => :close,
          :out => owr,          ord  => :close,
          :err => ewr,          erd  => :close
        )
      pid = spawn(*(argv + [opts]))

      [pid, iwr, ord, erd]
    ensure
      # we're in the parent, close child-side fds
      [ird, owr, ewr].each { |fd| fd.close }
    end

    # Wait for the child process to exit
    #
    # Returns the Process::Status object obtained by reaping the process.
    def waitpid(pid)
      ::Process::waitpid(pid)
      $?
    end

    # Use native Process::spawn implementation on Ruby 1.9.
    if ::Process.respond_to?(:spawn)
      def spawn(*argv)
        ::Process.spawn(*argv)
      end
    end
  end
end
