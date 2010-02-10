require 'grit/git-ruby/repository'
require 'grit/git-ruby/file_index'

module Grit

  # the functions in this module intercept the calls to git binary
  # made buy the grit objects and attempts to run them in pure ruby
  # if it will be faster, or if the git binary is not available (!!TODO!!)
  module GitRuby

    attr_accessor :ruby_git_repo, :git_file_index

    def init(options)
      if options.size == 0
        Grit::GitRuby::Repository.init(@git_dir)
      else
        method_missing('init', options)
      end
    end

    def cat_file(options, ref)
      if options[:t]
        file_type(ref)
      elsif options[:s]
        file_size(ref)
      elsif options[:p]
        try_run { ruby_git.cat_file(ref) }
      end
    rescue Grit::GitRuby::Repository::NoSuchShaFound
      ''
    end

    # lib/grit/tree.rb:16:      output = repo.git.ls_tree({}, treeish, *paths)
    def ls_tree(options, treeish, *paths)
      sha = rev_parse({}, treeish)
      ruby_git.ls_tree(sha, paths.flatten, options.delete(:r))
    rescue Grit::GitRuby::Repository::NoSuchShaFound
      ''
    end

    # git diff --full-index 'ec037431382e83c3e95d4f2b3d145afbac8ea55d' 'f1ec1aea10986159456846b8a05615b87828d6c6'
    def diff(options, sha1, sha2 = nil)
      try_run { ruby_git.diff(sha1, sha2, options) }
    end

    def rev_list(options, ref = 'master')
      options.delete(:skip) if options[:skip].to_i == 0
      allowed_options = [:max_count, :since, :until, :pretty]  # this is all I can do right now
      if ((options.keys - allowed_options).size > 0)
        return method_missing('rev-list', options, ref)
      elsif (options.size == 0)
        # pure rev-list
        begin
          return file_index.commits_from(rev_parse({}, ref)).join("\n") + "\n"
        rescue
          return method_missing('rev-list', options, ref)
        end
      else
        aref = rev_parse({}, ref)
        if aref.is_a? Array
          return method_missing('rev-list', options, ref)
        else
          return try_run { ruby_git.rev_list(aref, options) }
        end
      end
    end

    def rev_parse(options, string)
      raise RuntimeError, "invalid string: #{string}" unless string.is_a?(String)

      if string =~ /\.\./
        (sha1, sha2) = string.split('..')
        return [rev_parse({}, sha1), rev_parse({}, sha2)]
      end

      if /^[0-9a-f]{40}$/.match(string)  # passing in a sha - just no-op it
        return string.chomp
      end

      head = File.join(@git_dir, 'refs', 'heads', string)
      return File.read(head).chomp if File.file?(head)

      head = File.join(@git_dir, 'refs', 'remotes', string)
      return File.read(head).chomp if File.file?(head)

      head = File.join(@git_dir, 'refs', 'tags', string)
      return File.read(head).chomp if File.file?(head)

      ## check packed-refs file, too
      packref = File.join(@git_dir, 'packed-refs')
      if File.file?(packref)
        File.readlines(packref).each do |line|
          if m = /^(\w{40}) refs\/.+?\/(.*?)$/.match(line)
            next if !Regexp.new(Regexp.escape(string) + '$').match(m[3])
            return m[1].chomp
          end
        end
      end

      ## !! more - partials and such !!

      # revert to calling git - grr
      return method_missing('rev-parse', options, string).chomp
    end

    def refs(options, prefix)
      refs = []
      already = {}
      Dir.chdir(@git_dir) do
        files = Dir.glob(prefix + '/**/*')
        files.each do |ref|
          next if !File.file?(ref)
          id = File.read(ref).chomp
          name = ref.sub("#{prefix}/", '')
          if !already[name]
            refs << "#{name} #{id}"
            already[name] = true
          end
        end

        if File.file?('packed-refs')
          File.readlines('packed-refs').each do |line|
            if m = /^(\w{40}) (.*?)$/.match(line)
              next if !Regexp.new('^' + prefix).match(m[2])
              name = m[2].sub("#{prefix}/", '')
              if !already[name]
                refs << "#{name} #{m[1]}"
                already[name] = true
              end
            end
          end
        end
      end

      refs.join("\n")
    end

    def tags(options, prefix)
      refs = []
      already = {}

      Dir.chdir(repo.path) do
        files = Dir.glob(prefix + '/**/*')

        files.each do |ref|
          next if !File.file?(ref)

          id = File.read(ref).chomp
          name = ref.sub("#{prefix}/", '')

          if !already[name]
            refs << "#{name} #{id}"
            already[name] = true
          end
        end

        if File.file?('packed-refs')
          lines = File.readlines('packed-refs')
          lines.each_with_index do |line, i|
            if m = /^(\w{40}) (.*?)$/.match(line)
              next if !Regexp.new('^' + prefix).match(m[2])
              name = m[2].sub("#{prefix}/", '')

              # Annotated tags in packed-refs include a reference
              # to the commit object on the following line.
              next_line = lines[i + 1]

              id =
              if next_line && next_line[0] == ?^
                next_line[1..-1].chomp
              else
                m[1]
              end

              if !already[name]
                refs << "#{name} #{id}"
                already[name] = true
              end
            end
          end
        end
      end

      refs.join("\n")
    end

    def file_size(ref)
      try_run { ruby_git.cat_file_size(ref).to_s }
    end

    def file_type(ref)
      try_run { ruby_git.cat_file_type(ref).to_s }
    end

    def blame_tree(commit, path = nil)
      begin
        path = [path].join('/').to_s + '/' if (path && path != '')
        path = '' if !path.is_a? String
        commits = file_index.last_commits(rev_parse({}, commit), looking_for(commit, path))
        clean_paths(commits)
      rescue FileIndex::IndexFileNotFound
        {}
      end
    end

    def file_index
      @git_file_index ||= FileIndex.new(@git_dir)
    end

    def ruby_git
      @ruby_git_repo ||= Repository.new(@git_dir)
    end

    private

      def try_run
        ret = ''
        Timeout.timeout(self.class.git_timeout) do
          ret = yield
        end
        @bytes_read += ret.size

        #if @bytes_read > 5242880 # 5.megabytes
        #  bytes = @bytes_read
        #  @bytes_read = 0
        #  raise Grit::Git::GitTimeout.new(command, bytes)
        #end

        ret
      rescue Timeout::Error => e
        bytes = @bytes_read
        @bytes_read = 0
        raise Grit::Git::GitTimeout.new(command, bytes)
      end

      def looking_for(commit, path = nil)
        tree_sha = ruby_git.get_subtree(rev_parse({}, commit), path)

        looking_for = []
        ruby_git.get_object_by_sha1(tree_sha).entry.each do |e|
          if path && !(path == '' || path == '.' || path == './')
            file = File.join(path, e.name)
          else
            file = e.name
          end
          file += '/' if e.type == :directory
          looking_for << file
        end
        looking_for
      end

      def clean_paths(commit_array)
        new_commits = {}
        commit_array.each do |file, sha|
          file = file.chop if file[file.size - 1 , 1] == '/'
          new_commits[file] = sha
        end
        new_commits
      end

    # TODO
    # git grep -n 'foo' 'master'
    # git log --pretty='raw' --max-count='1' 'master' -- 'LICENSE'
    # git log --pretty='raw' --max-count='1' 'master' -- 'test'

  end
end
