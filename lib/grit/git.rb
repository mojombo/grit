require 'tempfile'
require 'posix-spawn'
module Grit

  class Git
    include POSIX::Spawn

    class GitTimeout < RuntimeError
      attr_accessor :command
      attr_accessor :bytes_read

      def initialize(command = nil, bytes_read = nil)
        @command = command
        @bytes_read = bytes_read
      end
    end

    # Raised when a native git command exits with non-zero.
    class CommandFailed < StandardError
      # The full git command that failed as a String.
      attr_reader :command

      # The integer exit status.
      attr_reader :exitstatus

      # Everything output on the command's stderr as a String.
      attr_reader :err

      def initialize(command, exitstatus=nil, err='')
        if exitstatus
          @command = command
          @exitstatus = exitstatus
          @err = err
          message = "Command failed [#{exitstatus}]: #{command}"
          message << "\n\n" << err unless err.nil? || err.empty?
          super message
        else
          super command
        end
      end
    end

    undef_method :clone

    include GitRuby

    def exist?
      File.exist?(self.git_dir)
    end

    def put_raw_object(content, type)
      ruby_git.put_raw_object(content, type)
    end

    def get_raw_object(object_id)
      ruby_git.get_raw_object_by_sha1(object_id).content
    end

    def get_git_object(object_id)
      ruby_git.get_raw_object_by_sha1(object_id).to_hash
    end

    def object_exists?(object_id)
      ruby_git.object_exists?(object_id)
    end

    def select_existing_objects(object_ids)
      object_ids.select do |object_id|
        object_exists?(object_id)
      end
    end

    class << self
      attr_accessor :git_timeout, :git_max_size
      def git_binary
        @git_binary ||=
          ENV['PATH'].split(':').
            map  { |p| File.join(p, 'git') }.
            find { |p| File.exist?(p) }
      end
      attr_writer :git_binary
    end

    self.git_timeout  = 10
    self.git_max_size = 5242880 # 5.megabytes

    def self.with_timeout(timeout = 10)
      old_timeout = Grit::Git.git_timeout
      Grit::Git.git_timeout = timeout
      yield
      Grit::Git.git_timeout = old_timeout
    end

    attr_accessor :git_dir, :bytes_read, :work_tree

    def initialize(git_dir)
      self.git_dir    = git_dir
      self.work_tree  = git_dir.gsub(/\/\.git$/,'')
      self.bytes_read = 0
    end

    def shell_escape(str)
      str.to_s.gsub("'", "\\\\'").gsub(";", '\\;')
    end
    alias_method :e, :shell_escape

    # Check if a normal file exists on the filesystem
    #   +file+ is the relative path from the Git dir
    #
    # Returns Boolean
    def fs_exist?(file)
      File.exist?(File.join(self.git_dir, file))
    end

    # Read a normal file from the filesystem.
    #   +file+ is the relative path from the Git dir
    #
    # Returns the String contents of the file
    def fs_read(file)
      File.read(File.join(self.git_dir, file))
    end

    # Write a normal file to the filesystem.
    #   +file+ is the relative path from the Git dir
    #   +contents+ is the String content to be written
    #
    # Returns nothing
    def fs_write(file, contents)
      path = File.join(self.git_dir, file)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |f|
        f.write(contents)
      end
    end

    # Delete a normal file from the filesystem
    #   +file+ is the relative path from the Git dir
    #
    # Returns nothing
    def fs_delete(file)
      FileUtils.rm_rf(File.join(self.git_dir, file))
    end

    # Move a normal file
    #   +from+ is the relative path to the current file
    #   +to+ is the relative path to the destination file
    #
    # Returns nothing
    def fs_move(from, to)
      FileUtils.mv(File.join(self.git_dir, from), File.join(self.git_dir, to))
    end

    # Make a directory
    #   +dir+ is the relative path to the directory to create
    #
    # Returns nothing
    def fs_mkdir(dir)
      FileUtils.mkdir_p(File.join(self.git_dir, dir))
    end

    # Chmod the the file or dir and everything beneath
    #   +file+ is the relative path from the Git dir
    #
    # Returns nothing
    def fs_chmod(mode, file = '/')
      FileUtils.chmod_R(mode, File.join(self.git_dir, file))
    end

    def list_remotes
      remotes = []
      Dir.chdir(File.join(self.git_dir, 'refs/remotes')) do
        remotes = Dir.glob('*')
      end
      remotes
    rescue
      []
    end

    def create_tempfile(seed, unlink = false)
      path = Tempfile.new(seed).path
      File.unlink(path) if unlink
      return path
    end

    def commit_from_sha(id)
      git_ruby_repo = GitRuby::Repository.new(self.git_dir)
      object = git_ruby_repo.get_object_by_sha1(id)

      if object.type == :commit
        id
      elsif object.type == :tag
        object.object
      else
        ''
      end
    end

    # Checks if the patch of a commit can be applied to the given head.
    #
    # options     - grit command options hash
    # head_sha    - String SHA or ref to check the patch against.
    # applies_sha - String SHA of the patch.  The patch itself is retrieved
    #               with #get_patch.
    #
    # Returns 0 if the patch applies cleanly (according to `git apply`), or
    # an Integer that is the sum of the failed exit statuses.
    def check_applies(options={}, head_sha=nil, applies_sha=nil)
      options, head_sha, applies_sha = {}, options, head_sha if !options.is_a?(Hash)
      options = options.dup
      options[:env] &&= options[:env].dup

      git_index = create_tempfile('index', true)
      (options[:env] ||= {}).merge!('GIT_INDEX_FILE' => git_index)
      options[:raise] = true

      status = 0
      begin
        native(:read_tree, options.dup, head_sha)
        stdin = native(:diff, options.dup, "#{applies_sha}^", applies_sha)
        native(:apply, options.merge(:check => true, :cached => true, :input => stdin))
      rescue CommandFailed => fail
        status += fail.exitstatus
      end
      status
    end

    # Gets a patch for a given SHA using `git diff`.
    #
    # options     - grit command options hash
    # applies_sha - String SHA to get the patch from, using this command:
    #               `git diff #{applies_sha}^ #{applies_sha}`
    #
    # Returns the String patch from `git diff`.
    def get_patch(options={}, applies_sha=nil)
      options, applies_sha = {}, options if !options.is_a?(Hash)
      options = options.dup
      options[:env] &&= options[:env].dup

      git_index = create_tempfile('index', true)
      (options[:env] ||= {}).merge!('GIT_INDEX_FILE' => git_index)

      native(:diff, options, "#{applies_sha}^", applies_sha)
    end

    # Applies the given patch against the given SHA of the current repo.
    #
    # options  - grit command hash
    # head_sha - String SHA or ref to apply the patch to.
    # patch    - The String patch to apply.  Get this from #get_patch.
    #
    # Returns the String Tree SHA on a successful patch application, or false.
    def apply_patch(options={}, head_sha=nil, patch=nil)
      options, head_sha, patch = {}, options, head_sha if !options.is_a?(Hash)
      options = options.dup
      options[:env] &&= options[:env].dup
      options[:raise] = true

      git_index = create_tempfile('index', true)
      (options[:env] ||= {}).merge!('GIT_INDEX_FILE' => git_index)

      begin
        native(:read_tree, options.dup, head_sha)
        native(:apply, options.merge(:cached => true, :input => patch))
      rescue CommandFailed
        return false
      end
      native(:write_tree, :env => options[:env]).to_s.chomp!
    end

    # Execute a git command, bypassing any library implementation.
    #
    # cmd - The name of the git command as a Symbol. Underscores are
    #   converted to dashes as in :rev_parse => 'rev-parse'.
    # options - Command line option arguments passed to the git command.
    #   Single char keys are converted to short options (:a => -a).
    #   Multi-char keys are converted to long options (:arg => '--arg').
    #   Underscores in keys are converted to dashes. These special options
    #   are used to control command execution and are not passed in command
    #   invocation:
    #     :timeout - Maximum amount of time the command can run for before
    #       being aborted. When true, use Grit::Git.git_timeout; when numeric,
    #       use that number of seconds; when false or 0, disable timeout.
    #     :base - Set false to avoid passing the --git-dir argument when
    #       invoking the git command.
    #     :env - Hash of environment variable key/values that are set on the
    #       child process.
    #     :raise - When set true, commands that exit with a non-zero status
    #       raise a CommandFailed exception. This option is available only on
    #       platforms that support fork(2).
    #     :process_info - By default, a single string with output written to
    #       the process's stdout is returned. Setting this option to true
    #       results in a [exitstatus, out, err] tuple being returned instead.
    # args - Non-option arguments passed on the command line.
    #
    # Optionally yields to the block an IO object attached to the child
    # process's STDIN.
    #
    # Examples
    #   git.native(:rev_list, {:max_count => 10, :header => true}, "master")
    #
    # Returns a String with all output written to the child process's stdout
    #   when the :process_info option is not set.
    # Returns a [exitstatus, out, err] tuple when the :process_info option is
    #   set. The exitstatus is an small integer that was the process's exit
    #   status. The out and err elements are the data written to stdout and
    #   stderr as Strings.
    # Raises Grit::Git::GitTimeout when the timeout is exceeded or when more
    #   than Grit::Git.git_max_size bytes are output.
    # Raises Grit::Git::CommandFailed when the :raise option is set true and the
    #   git command exits with a non-zero exit status. The CommandFailed's #command,
    #   #exitstatus, and #err attributes can be used to retrieve additional
    #   detail about the error.
    def native(cmd, options = {}, *args, &block)
      args     = args.first if args.size == 1 && args[0].is_a?(Array)
      args.map!    { |a| a.to_s }
      args.reject! { |a| a.empty? }

      # special option arguments
      env = options.delete(:env) || {}
      raise_errors = options.delete(:raise)
      process_info = options.delete(:process_info)

      # fall back to using a shell when the last argument looks like it wants to
      # start a pipeline for compatibility with previous versions of grit.
      return run(prefix, cmd, '', options, args) if args[-1].to_s[0] == ?|

      # more options
      input    = options.delete(:input)
      timeout  = options.delete(:timeout); timeout = true if timeout.nil?
      base     = options.delete(:base);    base    = true if base.nil?
      chdir    = options.delete(:chdir)

      # build up the git process argv
      argv = []
      argv << Git.git_binary
      argv << "--git-dir=#{git_dir}" if base
      argv << cmd.to_s.tr('_', '-')
      argv.concat(options_to_argv(options))
      argv.concat(args)

      # run it and deal with fallout
      Grit.log(argv.join(' ')) if Grit.debug

      process =
        Child.new(env, *(argv + [{
          :input   => input,
          :chdir   => chdir,
          :timeout => (Grit::Git.git_timeout if timeout == true),
          :max     => (Grit::Git.git_max_size if timeout == true)
        }]))
      Grit.log(process.out) if Grit.debug
      Grit.log(process.err) if Grit.debug

      status = process.status
      if raise_errors && !status.success?
        raise CommandFailed.new(argv.join(' '), status.exitstatus, process.err)
      elsif process_info
        [status.exitstatus, process.out, process.err]
      else
        process.out
      end
    rescue TimeoutExceeded, MaximumOutputExceeded
      raise GitTimeout, argv.join(' ')
    end

    # Methods not defined by a library implementation execute the git command
    # using #native, passing the method name as the git command name.
    #
    # Examples:
    #   git.rev_list({:max_count => 10, :header => true}, "master")
    def method_missing(cmd, options={}, *args, &block)
      native(cmd, options, *args, &block)
    end

    # Transform a ruby-style options hash to command-line arguments sutiable for
    # use with Kernel::exec. No shell escaping is performed.
    #
    # Returns an Array of String option arguments.
    def options_to_argv(options)
      argv = []
      options.each do |key, val|
        if key.to_s.size == 1
          if val == true
            argv << "-#{key}"
          elsif val == false
            # ignore
          else
            argv << "-#{key}"
            argv << val.to_s
          end
        else
          if val == true
            argv << "--#{key.to_s.tr('_', '-')}"
          elsif val == false
            # ignore
          else
            argv << "--#{key.to_s.tr('_', '-')}=#{val}"
          end
        end
      end
      argv
    end

    # Simple wrapper around Timeout::timeout.
    #
    # seconds - Float number of seconds before a Timeout::Error is raised. When
    #   true, the Grit::Git.git_timeout value is used. When the timeout is less
    #   than or equal to 0, no timeout is established.
    #
    # Raises Timeout::Error when the timeout has elapsed.
    def timeout_after(seconds)
      seconds = self.class.git_timeout if seconds == true
      if seconds && seconds > 0
        Timeout.timeout(seconds) { yield }
      else
        yield
      end
    end

    # DEPRECATED OPEN3-BASED COMMAND EXECUTION

    def run(prefix, cmd, postfix, options, args, &block)
      timeout  = options.delete(:timeout) rescue nil
      timeout  = true if timeout.nil?

      base     = options.delete(:base) rescue nil
      base     = true if base.nil?

      if input = options.delete(:input)
        block = lambda { |stdin| stdin.write(input) }
      end

      opt_args = transform_options(options)

      if RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|bccwin/
        ext_args = args.reject { |a| a.empty? }.map { |a| (a == '--' || a[0].chr == '|' || Grit.no_quote) ? a : "\"#{e(a)}\"" }
        gitdir = base ? "--git-dir=\"#{self.git_dir}\"" : ""
        call = "#{prefix}#{Git.git_binary} #{gitdir} #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + ext_args).join(' ')}#{e(postfix)}"
      else
        ext_args = args.reject { |a| a.empty? }.map { |a| (a == '--' || a[0].chr == '|' || Grit.no_quote) ? a : "'#{e(a)}'" }
        gitdir = base ? "--git-dir='#{self.git_dir}'" : ""
        call = "#{prefix}#{Git.git_binary} #{gitdir} #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + ext_args).join(' ')}#{e(postfix)}"
      end

      Grit.log(call) if Grit.debug
      response, err = timeout ? sh(call, &block) : wild_sh(call, &block)
      Grit.log(response) if Grit.debug
      Grit.log(err) if Grit.debug
      response
    end

    def sh(command, &block)
      process =
        Child.new(
          command,
          :timeout => Git.git_timeout,
          :max     => Git.git_max_size
        )
      [process.out, process.err]
    rescue TimeoutExceeded, MaximumOutputExceeded
      raise GitTimeout, command
    end

    def wild_sh(command, &block)
      process = Child.new(command)
      [process.out, process.err]
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
          elsif options[opt] == false
            # ignore
          else
            val = options.delete(opt)
            args << "-#{opt.to_s} '#{e(val)}'"
          end
        else
          if options[opt] == true
            args << "--#{opt.to_s.gsub(/_/, '-')}"
          elsif options[opt] == false
            # ignore
          else
            val = options.delete(opt)
            args << "--#{opt.to_s.gsub(/_/, '-')}='#{e(val)}'"
          end
        end
      end
      args
    end
  end # Git

end # Grit
