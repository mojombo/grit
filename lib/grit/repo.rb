module Grit

  class Repo
    DAEMON_EXPORT_FILE = 'git-daemon-export-ok'
    BATCH_PARSERS      = {
      'commit' => ::Grit::Commit
    }

    # Public: The String path of the Git repo.
    attr_accessor :path

    # Public: The String path to the working directory of the repo, or nil if
    # there is no working directory.
    attr_accessor :working_dir

    # Public: The Boolean of whether or not the repo is bare.
    attr_reader :bare

    # Public: The Grit::Git command line interface object.
    attr_accessor :git

    # Public: Create a new Repo instance.
    #
    # path    - The String path to either the root git directory or the bare
    #           git repo. Bare repos are expected to end with ".git".
    # options - A Hash of options (default: {}):
    #           :is_bare - Boolean whether to consider the repo as bare even
    #                      if the repo name does not end with ".git".
    #
    # Examples
    #
    #   r = Repo.new("/Users/tom/dev/normal")
    #   r = Repo.new("/Users/tom/public/bare.git")
    #   r = Repo.new("/Users/tom/public/bare", {:is_bare => true})
    #
    # Returns a newly initialized Grit::Repo.
    # Raises Grit::InvalidGitRepositoryError if the path exists but is not
    #   a Git repository.
    # Raises Grit::NoSuchPathError if the path does not exist.
    def initialize(path, options = {})
      epath = File.expand_path(path)

      if File.exist?(File.join(epath, '.git'))
        self.working_dir = epath
        self.path = File.join(epath, '.git')
        @bare = false
      elsif File.exist?(epath) && (epath =~ /\.git$/ || options[:is_bare])
        self.path = epath
        @bare = true
      elsif File.exist?(epath)
        raise InvalidGitRepositoryError.new(epath)
      else
        raise NoSuchPathError.new(epath)
      end

      self.git = Git.new(self.path)
    end

    # Public: Initialize a git repository (create it on the filesystem). By
    # default, the newly created repository will contain a working directory.
    # If you would like to create a bare repo, use Grit::Repo.init_bare.
    #
    # path         - The String full path to the repo. Traditionally ends with
    #                "/<name>.git".
    # git_options  - A Hash of additional options to the git init command
    #                (default: {}).
    # repo_options - A Hash of additional options to the Grit::Repo.new call
    #                (default: {}).
    #
    # Examples
    #
    #   Grit::Repo.init('/var/git/myrepo.git')
    #
    # Returns the newly created Grit::Repo.
    def self.init(path, git_options = {}, repo_options = {})
      git_options = {:base => false}.merge(git_options)
      git = Git.new(path)
      git.fs_mkdir('..')
      git.init(git_options, path)
      self.new(path, repo_options)
    end

    # Public: Initialize a bare git repository (create it on the filesystem).
    #
    # path         - The String full path to the repo. Traditionally ends with
    #                "/<name>.git".
    # git_options  - A Hash of additional options to the git init command
    #                (default: {}).
    # repo_options - A Hash of additional options to the Grit::Repo.new call
    #                (default: {}).
    #
    # Examples
    #
    #   Grit::Repo.init_bare('/var/git/myrepo.git')
    #
    # Returns the newly created Grit::Repo.
    def self.init_bare(path, git_options = {}, repo_options = {})
      git_options = {:bare => true}.merge(git_options)
      git = Git.new(path)
      git.fs_mkdir('..')
      git.init(git_options)
      repo_options = {:is_bare => true}.merge(repo_options)
      self.new(path, repo_options)
    end

    # Public: Initialize a bare Git repository (create it on the filesystem)
    # or, if the repo already exists, simply return it.
    #
    # path         - The String full path to the repo. Traditionally ends with
    #                "/<name>.git".
    # git_options  - A Hash of additional options to the git init command
    #                (default: {}).
    # repo_options - A Hash of additional options to the Grit::Repo.new call
    #                (default: {}).
    #
    # Returns the new or existing Grit::Repo.
    def self.init_bare_or_open(path, git_options = {}, repo_options = {})
      git = Git.new(path)

      unless git.exist?
        git.fs_mkdir(path)
        git.init(git_options)
      end

      self.new(path, repo_options)
    end

    # Public: Create a bare fork of this repository.
    #
    # path    - The String full path of where to create the new fork.
    #           Traditionally ends with "/<name>.git".
    # options - The Hash of additional options to the git clone command.
    #           These options will be merged on top of the default Hash:
    #           {:bare => true, :shared => true}.
    #
    # Returns the newly forked Grit::Repo.
    def fork_bare(path, options = {})
      default_options = {:bare => true, :shared => true}
      real_options = default_options.merge(options)
      Git.new(path).fs_mkdir('..')
      self.git.clone(real_options, self.path, path)
      Repo.new(path)
    end

    # Public: Fork a bare git repository from another repo.
    #
    # path    - The String full path of the repo from which to fork..
    #           Traditionally ends with "/<name>.git".
    # options - The Hash of additional options to the git clone command.
    #           These options will be merged on top of the default Hash:
    #           {:bare => true, :shared => true}.
    #
    # Returns the newly forked Grit::Repo.
    def fork_bare_from(path, options = {})
      default_options = {:bare => true, :shared => true}
      real_options = default_options.merge(options)
      Git.new(self.path).fs_mkdir('..')
      self.git.clone(real_options, path, self.path)
      Repo.new(self.path)
    end

    # Public: Return the full Git objects from the given SHAs.  Only Commit
    # objects are parsed for now.
    #
    # *shas - Array of String SHAs.
    #
    # Returns an Array of Grit objects (Grit::Commit).
    def batch(*shas)
      shas.flatten!
      text = git.native(:cat_file, {:batch => true, :input => (shas * "\n")})
      parse_batch(text)
    end

    # Parses `git cat-file --batch` output, returning an array of Grit objects.
    #
    # text - Raw String output.
    #
    # Returns an Array of Grit objects (Grit::Commit).
    def parse_batch(text)
      io = StringIO.new(text)
      objects = []
      while line = io.gets
        sha, type, size = line.split(" ", 3)
        parser = BATCH_PARSERS[type]
        if type == 'missing' || !parser
          io.seek(size.to_i + 1, IO::SEEK_CUR)
          objects << nil
          next
        end

        object   = io.read(size.to_i + 1)
        objects << parser.parse_batch(self, sha, size, object)
      end
      objects
    end

    # The project's description. Taken verbatim from GIT_REPO/description
    #
    # Returns String
    def description
      self.git.fs_read('description').chomp
    end

    def blame(file, commit = nil)
      Blame.new(self, file, commit)
    end

    # An array of Head objects representing the branch heads in
    # this repo
    #
    # Returns Grit::Head[] (baked)
    def heads
      Head.find_all(self)
    end

    alias_method :branches, :heads

    def get_head(head_name)
      heads.find { |h| h.name == head_name }
    end

    def is_head?(head_name)
      get_head(head_name)
    end

    # Object reprsenting the current repo head.
    #
    # Returns Grit::Head (baked)
    def head
      Head.current(self)
    end


    # Commits current index
    #
    # Returns true/false if commit worked
    def commit_index(message)
      self.git.commit({}, '-m', message)
    end

    # Commits all tracked and modified files
    #
    # Returns true/false if commit worked
    def commit_all(message)
      self.git.commit({}, '-a', '-m', message)
    end

    # Adds files to the index
    def add(*files)
      self.git.add({}, *files.flatten)
    end

    # Remove files from the index
    def remove(*files)
      self.git.rm({}, *files.flatten)
    end


    def blame_tree(commit, path = nil)
      commit_array = self.git.blame_tree(commit, path)

      final_array = {}
      commit_array.each do |file, sha|
        final_array[file] = commit(sha)
      end
      final_array
    end

    def status
      Status.new(self)
    end


    # An array of Tag objects that are available in this repo
    #
    # Returns Grit::Tag[] (baked)
    def tags
      Tag.find_all(self)
    end

    # Finds the most recent annotated tag name that is reachable from a commit.
    #
    #   @repo.recent_tag_name('master')
    #   # => "v1.0-0-abcdef"
    #
    # committish - optional commit SHA, branch, or tag name.
    # options    - optional hash of options to pass to git.
    #              Default: {:always => true}
    #              :tags => true      # use lightweight tags too.
    #              :abbrev => Integer # number of hex digits to form the unique
    #                name.  Defaults to 7.
    #              :long => true      # always output tag + commit sha
    #              # see `git describe` docs for more options.
    #
    # Returns the String tag name, or just the commit if no tag is
    # found.  If there have been updates since the tag was made, a
    # suffix is added with the number of commits since the tag, and
    # the abbreviated object name of the most recent commit.
    # Returns nil if the committish value is not found.
    def recent_tag_name(committish = nil, options = {})
      value = git.describe({:always => true}.update(options), committish.to_s).to_s.strip
      value.size.zero? ? nil : value
    end

    # An array of Remote objects representing the remote branches in
    # this repo
    #
    # Returns Grit::Remote[] (baked)
    def remotes
      Remote.find_all(self)
    end

    def remote_list
      self.git.list_remotes
    end

    def remote_add(name, url)
      self.git.remote({}, 'add', name, url)
    end

    def remote_fetch(name)
      self.git.fetch({}, name)
    end

    # takes an array of remote names and last pushed dates
    # fetches from all of the remotes where the local fetch
    # date is earlier than the passed date, then records the
    # last fetched date
    #
    # { 'origin' => date,
    #   'peter => date,
    # }
    def remotes_fetch_needed(remotes)
      remotes.each do |remote, date|
        # TODO: check against date
        self.remote_fetch(remote)
      end
    end


    # An array of Ref objects representing the refs in
    # this repo
    #
    # Returns Grit::Ref[] (baked)
    def refs
      [ Head.find_all(self), Tag.find_all(self), Remote.find_all(self) ].flatten
    end

    # returns an array of hashes representing all references
    def refs_list
      refs = self.git.for_each_ref
      refarr = refs.split("\n").map do |line|
        shatype, ref = line.split("\t")
        sha, type = shatype.split(' ')
        [ref, sha, type]
      end
      refarr
    end

    def delete_ref(ref)
      self.git.native(:update_ref, {:d => true}, ref)
    end

    def commit_stats(start = 'master', max_count = 10, skip = 0)
      options = {:max_count => max_count,
                 :skip => skip}

      CommitStats.find_all(self, start, options)
    end

    # An array of Commit objects representing the history of a given ref/commit
    #   +start+ is the branch/commit name (default 'master')
    #   +max_count+ is the maximum number of commits to return (default 10, use +false+ for all)
    #   +skip+ is the number of commits to skip (default 0)
    #
    # Returns Grit::Commit[] (baked)
    def commits(start = 'master', max_count = 10, skip = 0)
      options = {:max_count => max_count,
                 :skip => skip}

      Commit.find_all(self, start, options)
    end

    # The Commits objects that are reachable via +to+ but not via +from+
    # Commits are returned in chronological order.
    #   +from+ is the branch/commit name of the younger item
    #   +to+ is the branch/commit name of the older item
    #
    # Returns Grit::Commit[] (baked)
    def commits_between(from, to)
      Commit.find_all(self, "#{from}..#{to}").reverse
    end

    def fast_forwardable?(to, from)
      mb = self.git.native(:merge_base, {}, [to, from]).strip
      mb == from
    end

    # The Commits objects that are newer than the specified date.
    # Commits are returned in chronological order.
    #   +start+ is the branch/commit name (default 'master')
    #   +since+ is a string representing a date/time
    #   +extra_options+ is a hash of extra options
    #
    # Returns Grit::Commit[] (baked)
    def commits_since(start = 'master', since = '1970-01-01', extra_options = {})
      options = {:since => since}.merge(extra_options)

      Commit.find_all(self, start, options)
    end

    # The number of commits reachable by the given branch/commit
    #   +start+ is the branch/commit name (default 'master')
    #
    # Returns Integer
    def commit_count(start = 'master')
      Commit.count(self, start)
    end

    # The Commit object for the specified id
    #   +id+ is the SHA1 identifier of the commit
    #
    # Returns Grit::Commit (baked)
    def commit(id)
      options = {:max_count => 1}

      Commit.find_all(self, id, options).first
    end

    # Returns a list of commits that is in +other_repo+ but not in self
    #
    # Returns Grit::Commit[]
    def commit_deltas_from(other_repo, ref = "master", other_ref = "master")
      # TODO: we should be able to figure out the branch point, rather than
      # rev-list'ing the whole thing
      repo_refs       = self.git.rev_list({}, ref).strip.split("\n")
      other_repo_refs = other_repo.git.rev_list({}, other_ref).strip.split("\n")

      (other_repo_refs - repo_refs).map do |refn|
        Commit.find_all(other_repo, refn, {:max_count => 1}).first
      end
    end

    def objects(refs)
      refs = refs.split(/\s+/) if refs.respond_to?(:to_str)
      self.git.rev_list({:objects => true, :timeout => false}, *refs).
        split("\n").map { |a| a[0, 40] }
    end

    def commit_objects(refs)
      refs = refs.split(/\s+/) if refs.respond_to?(:to_str)
      self.git.rev_list({:timeout => false}, *refs).split("\n").map { |a| a[0, 40] }
    end

    def objects_between(ref1, ref2 = nil)
      if ref2
        refs = "#{ref2}..#{ref1}"
      else
        refs = ref1
      end
      self.objects(refs)
    end

    def diff_objects(commit_sha, parents = true)
      revs = []
      Grit.no_quote = true
      if parents
        # PARENTS:
        revs = self.git.diff_tree({:timeout => false, :r => true, :t => true, :m => true}, commit_sha).
          strip.split("\n").map{ |a| r = a.split(' '); r[3] if r[1] != '160000' }
      else
        # NO PARENTS:
        revs = self.git.native(:ls_tree, {:timeout => false, :r => true, :t => true}, commit_sha).
          split("\n").map{ |a| a.split("\t").first.split(' ')[2] }
      end
      revs << self.commit(commit_sha).tree.id
      Grit.no_quote = false
      return revs.uniq.compact
    end

    # The Tree object for the given treeish reference
    #   +treeish+ is the reference (default 'master')
    #   +paths+ is an optional Array of directory paths to restrict the tree (default [])
    #
    # Examples
    #   repo.tree('master', ['lib/'])
    #
    # Returns Grit::Tree (baked)
    def tree(treeish = 'master', paths = [])
      Tree.construct(self, treeish, paths)
    end

    # quick way to get a simple array of hashes of the entries
    # of a single tree or recursive tree listing from a given
    # sha or reference
    #   +treeish+ is the reference (default 'master')
    #   +options+ is a hash or options - currently only takes :recursive
    #
    # Examples
    #   repo.lstree('master', :recursive => true)
    #
    # Returns array of hashes - one per tree entry
    def lstree(treeish = 'master', options = {})
      # check recursive option
      opts = {:timeout => false, :l => true, :t => true}
      if options[:recursive]
        opts[:r] = true
      end
      # mode, type, sha, size, path
      revs = self.git.native(:ls_tree, opts, treeish)
      lines = revs.split("\n")
      revs = lines.map do |a|
        stuff, path = a.split("\t")
        mode, type, sha, size = stuff.split(" ")
        entry = {:mode => mode, :type => type, :sha => sha, :path => path}
        entry[:size] = size.strip.to_i if size.strip != '-'
        entry
      end
      revs
    end

    def object(sha)
      obj = git.get_git_object(sha)
      raw = Grit::GitRuby::Internal::RawObject.new(obj[:type], obj[:content])
      object = Grit::GitRuby::GitObject.from_raw(raw)
      object.sha = sha
      object
    end

    # The Blob object for the given id
    #   +id+ is the SHA1 id of the blob
    #
    # Returns Grit::Blob (unbaked)
    def blob(id)
      Blob.create(self, :id => id)
    end

    # The commit log for a treeish
    #
    # Returns Grit::Commit[]
    def log(commit = 'master', path = nil, options = {})
      default_options = {:pretty => "raw"}
      actual_options  = default_options.merge(options)
      arg = path ? [commit, '--', path] : [commit]
      commits = self.git.log(actual_options, *arg)
      Commit.list_from_string(self, commits)
    end

    # The diff from commit +a+ to commit +b+, optionally restricted to the given file(s)
    #   +a+ is the base commit
    #   +b+ is the other commit
    #   +paths+ is an optional list of file paths on which to restrict the diff
    def diff(a, b, *paths)
      diff = self.git.native('diff', {}, a, b, '--', *paths)

      if diff =~ /diff --git a/
        diff = diff.sub(/.*?(diff --git a)/m, '\1')
      else
        diff = ''
      end
      Diff.list_from_string(self, diff)
    end

    # The commit diff for the given commit
    #   +commit+ is the commit name/id
    #
    # Returns Grit::Diff[]
    def commit_diff(commit)
      Commit.diff(self, commit)
    end

    # Archive the given treeish
    #   +treeish+ is the treeish name/id (default 'master')
    #   +prefix+ is the optional prefix
    #
    # Examples
    #   repo.archive_tar
    #   # => <String containing tar archive>
    #
    #   repo.archive_tar('a87ff14')
    #   # => <String containing tar archive for commit a87ff14>
    #
    #   repo.archive_tar('master', 'myproject/')
    #   # => <String containing tar archive and prefixed with 'myproject/'>
    #
    # Returns String (containing tar archive)
    def archive_tar(treeish = 'master', prefix = nil)
      options = {}
      options[:prefix] = prefix if prefix
      self.git.archive(options, treeish)
    end

    # Archive and gzip the given treeish
    #   +treeish+ is the treeish name/id (default 'master')
    #   +prefix+ is the optional prefix
    #
    # Examples
    #   repo.archive_tar_gz
    #   # => <String containing tar.gz archive>
    #
    #   repo.archive_tar_gz('a87ff14')
    #   # => <String containing tar.gz archive for commit a87ff14>
    #
    #   repo.archive_tar_gz('master', 'myproject/')
    #   # => <String containing tar.gz archive and prefixed with 'myproject/'>
    #
    # Returns String (containing tar.gz archive)
    def archive_tar_gz(treeish = 'master', prefix = nil)
      options = {}
      options[:prefix] = prefix if prefix
      self.git.archive(options, treeish, "| gzip -n")
    end

    # Write an archive directly to a file
    #   +treeish+ is the treeish name/id (default 'master')
    #   +prefix+ is the optional prefix (default nil)
    #   +filename+ is the name of the file (default 'archive.tar.gz')
    #   +format+ is the optional format (default nil)
    #   +pipe+ is the command to run the output through (default 'gzip')
    #
    # Returns nothing
    def archive_to_file(treeish = 'master', prefix = nil, filename = 'archive.tar.gz', format = nil, pipe = "gzip")
      options = {}
      options[:prefix] = prefix if prefix
      options[:format] = format if format
      self.git.archive(options, treeish, "| #{pipe} > #{filename}")
    end

    # Enable git-daemon serving of this repository by writing the
    # git-daemon-export-ok file to its git directory
    #
    # Returns nothing
    def enable_daemon_serve
      self.git.fs_write(DAEMON_EXPORT_FILE, '')
    end

    # Disable git-daemon serving of this repository by ensuring there is no
    # git-daemon-export-ok file in its git directory
    #
    # Returns nothing
    def disable_daemon_serve
      self.git.fs_delete(DAEMON_EXPORT_FILE)
    end

    def gc_auto
      self.git.gc({:auto => true})
    end

    # The list of alternates for this repo
    #
    # Returns Array[String] (pathnames of alternates)
    def alternates
      alternates_path = "objects/info/alternates"
      self.git.fs_read(alternates_path).strip.split("\n")
    rescue Errno::ENOENT
      []
    end

    # Sets the alternates
    #   +alts+ is the Array of String paths representing the alternates
    #
    # Returns nothing
    def alternates=(alts)
      alts.each do |alt|
        unless File.exist?(alt)
          raise "Could not set alternates. Alternate path #{alt} must exist"
        end
      end

      if alts.empty?
        self.git.fs_write('objects/info/alternates', '')
      else
        self.git.fs_write('objects/info/alternates', alts.join("\n"))
      end
    end

    def config
      @config ||= Config.new(self)
    end

    def index
      Index.new(self)
    end

    def update_ref(head, commit_sha)
      return nil if !commit_sha || (commit_sha.size != 40)
      self.git.fs_write("refs/heads/#{head}", commit_sha)
      commit_sha
    end

    # Rename the current repository directory.
    #   +name+ is the new name
    #
    # Returns nothing
    def rename(name)
      if @bare
        self.git.fs_move('/', "../#{name}")
      else
        self.git.fs_move('/', "../../#{name}")
      end
    end

    # Pretty object inspection
    def inspect
      %Q{#<Grit::Repo "#{@path}">}
    end
  end # Repo

end # Grit
