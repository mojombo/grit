module Grit
  
  class Repo
    # The path of the git repo as a String
    attr_accessor :path
    
    # The git command line interface object
    attr_accessor :git
  
    # Create a new Repo instance
    #   +path+ is the path to either the root git directory or the bare git repo
    #
    # Examples
    #   g = Repo.new("/Users/tom/dev/grit")
    #   g = Repo.new("/Users/tom/public/grit.git")
    #
    # Returns Repo
    def initialize(path)
      if File.exist?(File.join(path, '.git'))
        self.path = File.join(path, '.git')
      elsif File.exist?(path) && path =~ /\.git$/
        self.path = path
      else
        raise InvalidGitRepositoryError.new(path) unless File.exist?(path)
      end
      
      self.git = Git.new(self.path)
    end
  
    # The project's description. Taken verbatim from GIT_REPO/description
    #
    # Returns String
    def description
      File.open(File.join(self.path, 'description')).read.chomp
    end
  
    # An array of Head objects representing the available heads in
    # this repo
    #
    # Returns Grit::Head[]
    def heads
      Head.find_all(self)
    end
    
    alias_method :branches, :heads
    
    # An array of Commit objects representing the history of a given branch/commit
    #   +start+ is the branch/commit name (default 'master')
    #   +max_count+ is the maximum number of commits to return (default 10)
    #   +skip+ is the number of commits to skip (default 0)
    #
    # Returns Grit::Commit[]
    def commits(start = 'master', max_count = 10, skip = 0)
      options = {:max_count => max_count,
                 :skip => skip}
      
      Commit.find_all(self, start, options)
    end
    
    # The Commit object for the specified ref
    #   +id+ is the SHA1 identifier of the commit
    #
    # Returns Grit::Commit
    def commit(id)
      options = {:max_count => 1}
      
      Commit.find_all(self, id, options).first
    end
    
    def tree(treeish = 'master', paths = [])
      output = @git.ls_tree(treeish, paths.join(" "))
      
      puts output
    end
  end # Repo
  
end # Grit