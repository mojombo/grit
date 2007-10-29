module Grit
  
  class Repo
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
    #   Repo.tree('master', ['lib/'])
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
      arg = path ? "#{commit} -- #{path}" : commit
      commits = self.git.log(actual_options, arg)
      Commit.list_from_string(self, commits)
    end
    
    # The diff from commit +a+ to commit +b+, optionally restricted to the given file(s)
    #   +a+ is the base commit
    #   +b+ is the other commit
    #   +paths+ is an optional list of file paths on which to restrict the diff
    def diff(a, b, *paths)
      self.git.diff({}, a, b, '--', *paths)
    end
    
    # Initialize a bare git repository at the given path
    #   +path+ is the full path to the repo (traditionally ends with /<name>.git)
    #
    # Examples
    #   Grit::Repo.init_bare('/var/git/myrepo.git')
    #
    # Returns Grit::Repo (the newly created repo)
    def self.init_bare(path)
      git = Git.new(path)
      git.init
      self.new(path)
    end
    
    # Pretty object inspection
    def inspect
      %Q{#<Grit::Repo "#{@path}">}
    end
  end # Repo
  
end # Grit
