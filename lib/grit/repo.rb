module Grit
  
  class Repo
    # The path of the git repo as a String
    attr_accessor :path
  
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
      
      @git = Git.new(self.path)
    end
  
    # The project's description. Taken verbatim from REPO/description
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
      output = @git.for_each_ref(
                 "--sort=-committerdate",
                 # "--count=1",
                 "--format='%(objectname) %(refname) %(subject)%00%(committer)'",
                 "refs/heads")
                 
      Head.list_from_string(output)
    end
    
    def branches
      @git.branch('--no-color').split("\n").map { |b| b.sub(/\*/, '').lstrip }
    end
    
    # An array of Commit objects representing the history of a given branch/commit
    #   +start+ is the branch/commit name (default 'master')
    #   +max_count+ is the maximum number of commits to return (default 1)
    #   +skip+ is the number of commits to skip (default 0)
    #
    # Returns Grit::Commit[]
    def commits(start = 'master', max_count = 1, skip = 0)
      output = @git.rev_list(
                 "--pretty=raw",
                 "--max-count=#{max_count}",
                 "--skip=#{skip}",
                 start)
                 
      Commit.list_from_string(output)
    end
    
    # The Commit object for the specified id
    #   +id+ is the SHA1 identifier of the commit
    #
    # Returns Grit::Commit
    def commit(id)
      output = @git.rev_list(
                 "--pretty=raw",
                 "--max-count=1",
                 id)
                 
      Commit.list_from_string(output).first
    end
    
    def tree(treeish = 'master', paths = [])
      output = @git.ls_tree(treeish, paths.join(" "))
      
      puts output
    end
  end # Repo
  
end # Grit