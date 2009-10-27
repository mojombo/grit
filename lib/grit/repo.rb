module Grit

  class Repo
    DAEMON_EXPORT_FILE = 'git-daemon-export-ok'

    # The path of the git repo as a String
    attr_accessor :path
    attr_accessor :working_dir
    attr_reader :bare

    # The git command line interface object
    attr_accessor :git

    # Create a new Repo instance
    #   +path+ is the path to either the root git directory or the bare git repo
    #   +options+ :is_bare force to load a bare repo
    #
    # Examples
    #   g = Repo.new("/Users/tom/dev/grit")
    #   g = Repo.new("/Users/tom/public/grit.git")
    #
    # Returns Grit::Repo
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

    # Does nothing yet...
    def self.init(path)
      # !! TODO !!
      # create directory
      # generate initial git directory
      # create new Grit::Repo on that dir, return it
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

    # The Commits objects that are newer than the specified date.
    # Commits are returned in chronological order.
    #   +start+ is the branch/commit name (default 'master')
    #   +since+ is a string represeting a date/time
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

      (other_repo_refs - repo_refs).map do |ref|
        Commit.find_all(other_repo, ref, {:max_count => 1}).first
      end
    end

    # The Tree object for the given treeish reference
    #   +treeish+ is the reference (default 'master')
    #   +paths+ is an optional Array of directory paths to restrict the tree (deafult [])
    #
    # Examples
    #   repo.tree('master', ['lib/'])
    #
    # Returns Grit::Tree (baked)
    def tree(treeish = 'master', paths = [])
      Tree.construct(self, treeish, paths)
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
      self.git.diff({}, a, b, '--', *paths)
    end

    # The commit diff for the given commit
    #   +commit+ is the commit name/id
    #
    # Returns Grit::Diff[]
    def commit_diff(commit)
      Commit.diff(self, commit)
    end

    # Initialize a bare git repository at the given path
    #   +path+ is the full path to the repo (traditionally ends with /<name>.git)
    #   +options+ is any additional options to the git init command
    #
    # Examples
    #   Grit::Repo.init_bare('/var/git/myrepo.git')
    #
    # Returns Grit::Repo (the newly created repo)
    def self.init_bare(path, git_options = {}, repo_options = {})
      git_options = {:bare => true}.merge(git_options)
      git = Git.new(path)
      git.fs_mkdir('..')
      git.init(git_options)
      self.new(path, repo_options)
    end

    # Fork a bare git repository from this repo
    #   +path+ is the full path of the new repo (traditionally ends with /<name>.git)
    #   +options+ is any additional options to the git clone command (:bare and :shared are true by default)
    #
    # Returns Grit::Repo (the newly forked repo)
    def fork_bare(path, options = {})
      default_options = {:bare => true, :shared => true}
      real_options = default_options.merge(options)
      Git.new(path).fs_mkdir('..')
      self.git.clone(real_options, self.path, path)
      Repo.new(path)
    end

    # Fork a bare git repository from another repo
    #   +path+ is the full path of the new repo (traditionally ends with /<name>.git)
    #   +options+ is any additional options to the git clone command (:bare and :shared are true by default)
    #
    # Returns Grit::Repo (the newly forked repo)
    def fork_bare_from(path, options = {})
      default_options = {:bare => true, :shared => true}
      real_options = default_options.merge(options)
      Git.new(self.path).fs_mkdir('..')
      self.git.clone(real_options, path, self.path)
      Repo.new(self.path)
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
      if self.git.fs_exist?(alternates_path)
        self.git.fs_read(alternates_path).strip.split("\n")
      else
        []
      end
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
