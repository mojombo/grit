module Grit
  
  class Repo
    DAEMON_EXPORT_FILE = 'git-daemon-export-ok'
    
    # The path of the git repo as a String
    attr_accessor :path
    attr_reader :bare
    
    # The git command line interface object
    attr_accessor :git
    
    # Create a new Repo instance
    #   +path+ is the path to either the root git directory or the bare git repo
    #
    # Examples
    #   g = Repo.new("/Users/tom/dev/grit")
    #   g = Repo.new("/Users/tom/public/grit.git")
    #
    # Returns Grit::Repo
    def initialize(path)
      epath = File.expand_path(path)
      
      if File.exist?(File.join(epath, '.git'))
        self.path = File.join(epath, '.git')
        @bare = false
      elsif File.exist?(epath) && epath =~ /\.git$/
        self.path = epath
        @bare = true
      elsif File.exist?(epath)
        raise InvalidGitRepositoryError.new(epath)
      else
        raise NoSuchPathError.new(epath)
      end
      
      self.git = Git.new(self.path)
    end
    
    # The project's description. Taken verbatim from GIT_REPO/description
    #
    # Returns String
    def description
      File.open(File.join(self.path, 'description')).read.chomp
    end
    
    # An array of Head objects representing the branch heads in
    # this repo
    #
    # Returns Grit::Head[] (baked)
    def heads
      Head.find_all(self)
    end
    
    alias_method :branches, :heads
    
    # An array of Commit objects representing the history of a given ref/commit
    #   +start+ is the branch/commit name (default 'master')
    #   +max_count+ is the maximum number of commits to return (default 10)
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
    #
    # Returns Grit::Commit[] (baked)
    def commits_since(start = 'master', since = '1970-01-01')
      options = {:since => since}
      
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
    def self.init_bare(path, options = {})
      git = Git.new(path)
      git.init(options)
      self.new(path)
    end
    
    # Fork a bare git repository from this repo
    #   +path+ is the full path of the new repo (traditionally ends with /<name>.git)
    #   +options+ is any additional options to the git clone command
    #
    # Returns Grit::Repo (the newly forked repo)
    def fork_bare(path, options = {})
      default_options = {:bare => true, :shared => true}
      real_options = default_options.merge(options)
      self.git.clone(real_options, self.path, path)
      Repo.new(path)
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
      self.git.archive(options, treeish, "| gzip")
    end
    
    # Enable git-daemon serving of this repository by writing the
    # git-daemon-export-ok file to its git directory
    #
    # Returns nothing
    def enable_daemon_serve
      if @bare
        FileUtils.touch(File.join(self.path, DAEMON_EXPORT_FILE))
      else
        FileUtils.touch(File.join(self.path, '.git', DAEMON_EXPORT_FILE))
      end
    end
    
    # Disable git-daemon serving of this repository by ensuring there is no
    # git-daemon-export-ok file in its git directory
    #
    # Returns nothing
    def disable_daemon_serve
      if @bare
        FileUtils.rm_f(File.join(self.path, DAEMON_EXPORT_FILE))
      else
        FileUtils.rm_f(File.join(self.path, '.git', DAEMON_EXPORT_FILE))
      end
    end
    
    # Pretty object inspection
    def inspect
      %Q{#<Grit::Repo "#{@path}">}
    end
  end # Repo
  
end # Grit
