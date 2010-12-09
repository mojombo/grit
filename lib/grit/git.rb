require 'tempfile'
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

    def exist?
      File.exist?(self.git_dir)
    end

    def put_raw_object(content, type)
      ruby_git.put_raw_object(content, type)
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
      attr_accessor :git_binary, :git_timeout, :git_max_size
    end

    if RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|bccwin/
      self.git_binary   = "git" # using search path
    else
      self.git_binary   = "/usr/bin/env git"
    end
    self.git_timeout  = 10
    self.git_max_size = 5242880 # 5.megabytes

    def self.with_timeout(timeout = 10.seconds)
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

    # Checks if a SHA's diff applies against the HEAD of the current 
    # repository.  This determines if a cherry-pick from a commit in the same
    # repository would be successful.
    #
    # head_sha    - String HEAD SHA of the repository.
    # applies_sha - String SHA of the commit to cherry-pick.
    #
    # Returns the exit status of the commands.  Anything above 0 means there
    # was an error.
    def check_applies(head_sha, applies_sha)
      check_patch_applies(head_sha, get_patch(applies_sha))
    end

    # Checks if a diff applies against the HEAD of the current repository.
    #
    # head_sha - String HEAD SHA of the repository.
    # patch    - String patch to apply (see #get_patch)
    #
    # Returns the exit status of the commands.  Anything above 0 means there
    # was an error.
    def check_patch_applies(head_sha, patch)
      apply_patch(head_sha, patch, :check => true) ? 0 : 1
    end

    # Gets the patch for a given commit.
    #
    # sha1    - String base SHA of the diff.
    # sha2    - Optional head SHA of the diff.  If not provided, use 
    #           sha1^...sha1
    # options - Optional Hash to be passed to the `git diff` command.
    #
    # Returns a String of the patch of the commit's parent to the parent.
    def get_patch(sha1, sha2 = nil, options = {})
      if sha2.is_a?(Hash)
        options = sha2
        sha2    = nil
      end

      sha1, sha2 = "#{sha1}^", sha1 if sha2.nil?
      native(:diff, options, sha1, sha2)
    end

    # Applies a patch against the current repository's INDEX.
    #
    # head_sha - String HEAD SHA of the repository to start from.
    # patch    - The String patch data.
    #
    # Returns a String SHA of the written tree, or false if the patch did not
    # apply cleanly.
    def apply_patch(head_sha, patch, options = {})
      options[:cached] = true
      tree_sha = nil
      with_custom_index do
        native(:read_tree, {}, head_sha)
        cmd = sh_command('', :apply, '', options, [])
        (ret, err) = sh(cmd) do |stdin|
          stdin << patch
          stdin.close
        end
        if err =~ /error/
          tree_sha = false
        elsif options[:check]
          tree_sha = true
        else
          tree_sha = native(:write_tree)
          tree_sha.strip!
        end
      end
      tree_sha
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
    def method_missing(cmd, options = {}, *args, &block)
      run('', cmd, '', options, args, &block)
    end

    # Bypass any pure Ruby implementations and go straight to the native Git command
    #
    # Returns String
    def native(cmd, options = {}, *args, &block)
      method_missing(cmd, options, *args, &block)
    end

    def run(prefix, cmd, postfix, options, args, &block)
      timeout  = options.delete(:timeout) rescue nil
      timeout  = true if timeout.nil?
      call     = sh_command(prefix, cmd, postfix, options, args)
      Grit.log(call) if Grit.debug
      response, err = timeout ? sh(call, &block) : wild_sh(call, &block)
      if Grit.debug
        Grit.log(response)
        Grit.log(err)
      end
      response
    end

    def sh_command(prefix, cmd, postfix, options, args)
      base     = options.delete(:base) rescue nil
      base     = true if base.nil?

      opt_args = transform_options(options)

      if RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|bccwin/
        ext_args = args.reject { |a| a.empty? }.map { |a| (a == '--' || a[0].chr == '|' || Grit.no_quote) ? a : "\"#{e(a)}\"" }
        gitdir = base ? "--git-dir=\"#{self.git_dir}\"" : ""
        "#{prefix}#{Git.git_binary} #{gitdir} #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + ext_args).join(' ')}#{e(postfix)}"
      else
        ext_args = args.reject { |a| a.empty? }.map { |a| (a == '--' || a[0].chr == '|' || Grit.no_quote) ? a : "'#{e(a)}'" }
        gitdir = base ? "--git-dir='#{self.git_dir}'" : ""
        "#{prefix}#{Git.git_binary} #{gitdir} #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + ext_args).join(' ')}#{e(postfix)}"
      end
    end

    def sh(command, &block)
      ret, err = '', ''
      max = self.class.git_max_size
      Open3.popen3(command) do |stdin, stdout, stderr|
        block.call(stdin) if block
        Timeout.timeout(self.class.git_timeout) do
          while tmp = stdout.read(8192)
            ret << tmp
            raise GitTimeout.new(command, ret.size) if ret.size > max
          end
        end

        while tmp = stderr.read(8192)
          err << tmp
        end
      end
      [ret, err]
    rescue Timeout::Error, Grit::Git::GitTimeout
      raise GitTimeout.new(command, ret.size)
    end

    def wild_sh(command, &block)
      ret, err = '', ''
      Open3.popen3(command) do |stdin, stdout, stderr|
        block.call(stdin) if block
        while tmp = stdout.read(8192)
          ret << tmp
        end

        while tmp = stderr.read(8192)
          err << tmp
        end
      end
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

    # Creates a temporary file in the filesystem.
    #
    # seed   - A string used in the name of the file.
    # unlink - Determines whether to delete the temp file.  Default: false
    #
    # Returns the String path to the Tempfile
    def create_tempfile(seed, unlink = false)
      path = Tempfile.new(seed).path
      File.unlink(path) if unlink
      return path
    end

    def with_custom_index(index = nil)
      index ||= create_tempfile('index', true)
      tmp     = ENV['GIT_INDEX_FILE']
      ENV['GIT_INDEX_FILE'] = index
      return_value = yield
      after = ENV['GIT_INDEX_FILE'] # someone fucking with us ??
      if after != index
        raise 'environment was changed for the git call'
      end
      return_value
    ensure
      ENV['GIT_INDEX_FILE'] = tmp
    end
  end # Git
end # Grit
