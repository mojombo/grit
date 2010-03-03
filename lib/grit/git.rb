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

    def check_applies(head_sha, applies_sha)
      git_index = create_tempfile('index', true)
      (o1, exit1) = raw_git("git read-tree #{head_sha} 2>/dev/null", git_index)
      (o2, exit2) = raw_git("git diff #{applies_sha}^ #{applies_sha} | git apply --check --cached >/dev/null 2>/dev/null", git_index)
      return (exit1 + exit2)
    end

    def get_patch(applies_sha)
      git_index = create_tempfile('index', true)
      (patch, exit2) = raw_git("git diff #{applies_sha}^ #{applies_sha}", git_index)
      patch
    end

    def apply_patch(head_sha, patch)
      git_index = create_tempfile('index', true)

      git_patch = create_tempfile('patch')
      File.open(git_patch, 'w+') { |f| f.print patch }

      raw_git("git read-tree #{head_sha} 2>/dev/null", git_index)
      (op, exit) = raw_git("git apply --cached < #{git_patch}", git_index)
      if exit == 0
        return raw_git("git write-tree", git_index).first.chomp
      end
      false
    end

    # RAW CALLS WITH ENV SETTINGS
    def raw_git_call(command, index)
      tmp = ENV['GIT_INDEX_FILE']
      ENV['GIT_INDEX_FILE'] = index
      out = `#{command}`
      after = ENV['GIT_INDEX_FILE'] # someone fucking with us ??
      ENV['GIT_INDEX_FILE'] = tmp
      if after != index
        raise 'environment was changed for the git call'
      end
      [out, $?.exitstatus]
    end

    def raw_git(command, index)
      output = nil
      Dir.chdir(self.git_dir) do
        output = raw_git_call(command, index)
      end
      output
    end
    # RAW CALLS WITH ENV SETTINGS END



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

    # Bypass any pure Ruby implementations and go straight to the native Git command
    #
    # Returns String
    def native(cmd, options = {}, *args)
      method_missing(cmd, options, *args)
    end

    def run(prefix, cmd, postfix, options, args)
      timeout  = options.delete(:timeout) rescue nil
      timeout  = true if timeout.nil?

      opt_args = transform_options(options)

      if RUBY_PLATFORM.downcase =~ /mswin(?!ce)|mingw|bccwin/
        ext_args = args.reject { |a| a.empty? }.map { |a| (a == '--' || a[0].chr == '|') ? a : "\"#{e(a)}\"" }
        call = "#{prefix}#{Git.git_binary} --git-dir=\"#{self.git_dir}\" #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + ext_args).join(' ')}#{e(postfix)}"
      else
        ext_args = args.reject { |a| a.empty? }.map { |a| (a == '--' || a[0].chr == '|') ? a : "'#{e(a)}'" }
        call = "#{prefix}#{Git.git_binary} --git-dir='#{self.git_dir}' #{cmd.to_s.gsub(/_/, '-')} #{(opt_args + ext_args).join(' ')}#{e(postfix)}"
      end

      Grit.log(call) if Grit.debug
      response, err = timeout ? sh(call) : wild_sh(call)
      Grit.log(response) if Grit.debug
      Grit.log(err) if Grit.debug
      response
    end

    def sh(command)
      ret, err = '', ''
      Open3.popen3(command) do |_, stdout, stderr|
        Timeout.timeout(self.class.git_timeout) do
          while tmp = stdout.read(1024)
            ret += tmp
            if (@bytes_read += tmp.size) > self.class.git_max_size
              bytes = @bytes_read
              @bytes_read = 0
              raise GitTimeout.new(command, bytes)
            end
          end
        end

        while tmp = stderr.read(1024)
          err += tmp
        end
      end
      [ret, err]
    rescue Timeout::Error, Grit::Git::GitTimeout
      bytes = @bytes_read
      @bytes_read = 0
      raise GitTimeout.new(command, bytes)
    end

    def wild_sh(command)
      ret, err = '', ''
      Open3.popen3(command) do |_, stdout, stderr|
        while tmp = stdout.read(1024)
          ret += tmp
        end

        while tmp = stderr.read(1024)
          err += tmp
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
  end # Git

end # Grit
