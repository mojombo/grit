module Grit
  
  class Commit
    attr_reader :id
    lazy_reader :parents
    lazy_reader :tree
    lazy_reader :author
    lazy_reader :authored_date
    lazy_reader :committer
    lazy_reader :committed_date
    lazy_reader :message
    
    # Instantiate a new Commit
    #   +id+ is the id of the commit
    #   +parents+ is an array of commit ids (will be converted into Commit instances)
    #   +tree+ is the correspdonding tree id (will be converted into a Tree object)
    #   +author+ is the author string
    #   +authored_date+ is the authored Time
    #   +committer+ is the committer string
    #   +committed_date+ is the committed Time
    #   +message+ is the first line of the commit message
    #
    # Returns Grit::Commit (baked)
    def initialize(repo, id, parents, tree, author, authored_date, committer, committed_date, message)
      @repo = repo
      @id = id
      @parents = parents.map { |p| Commit.create(repo, :id => p) }
      @tree = Tree.create(repo, :id => tree)
      @author = author
      @authored_date = authored_date
      @committer = committer
      @committed_date = committed_date
      @message = message
    end
    
    # Create an unbaked Commit containing just the specified attributes
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Commit (unbaked)
    def self.create(repo, atts)
      self.allocate.create_initialize(repo, atts)
    end
    
    # Initializer for Commit.create
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Commit (unbaked)
    def create_initialize(repo, atts)
      @repo = repo
      atts.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
      self
    end
    
    def lazy_source
      self.class.find_all(@repo, @id, {:max_count => 1}).first
    end
    
    # Find all commits matching the given criteria.
    #   +repo+ is the Repo
    #   +ref+ is the ref from which to begin (SHA1 or name)
    #   +options+ is a Hash of optional arguments to git
    #     :max_count is the maximum number of commits to fetch
    #     :skip is the number of commits to skip
    #
    # Returns Grit::Commit[] (baked)
    def self.find_all(repo, ref, options = {})
      allowed_options = [:max_count, :skip]
      
      default_options = {:pretty => "raw"}
      actual_options = default_options.merge(options)
      
      output = repo.git.rev_list(actual_options, ref)
      
      self.list_from_string(repo, output)
    end
    
    # Parse out commit information into an array of baked Commit objects
    #   +repo+ is the Repo
    #   +text+ is the text output from the git command (raw format)
    #
    # Returns Grit::Commit[] (baked)
    def self.list_from_string(repo, text)
      # remove empty lines
      lines = text.split("\n").select { |l| !l.strip.empty? }
      
      commits = []
      
      while !lines.empty?
        id = lines.shift.split.last
        tree = lines.shift.split.last
        
        parents = []
        parents << lines.shift.split.last while lines.first =~ /^parent/
        
        author, authored_date = self.actor(lines.shift)
        committer, committed_date = self.actor(lines.shift)
        
        messages = []
        messages << lines.shift.strip while lines.first =~ /^ {4}/
        message = messages.first || ''
        
        commits << Commit.new(repo, id, parents, tree, author, authored_date, committer, committed_date, message)
      end
      
      commits
    end
    
    def self.diff(repo, a, b = nil)
      text = repo.git.diff({:full_index => true}, a, b)
      Diff.list_from_string(repo, text)
    end

    def diffs
      self.class.diff(@repo, parents.first.id, @id) 
    end
    
    # Convert this Commit to a String which is just the SHA1 id
    def to_s
      @id
    end
    
    # Pretty object inspection
    def inspect
      %Q{#<Grit::Commit "#{@id}">}
    end
    
    # private
    
    # Parse out the actor (author or committer) info
    #
    # Returns [String (actor name and email), Time (acted at time)]
    def self.actor(line)
      m, actor, epoch = *line.match(/^.+? (.*) (\d+) .*$/)
      [Actor.from_string(actor), Time.at(epoch.to_i)]
    end
  end # Commit
  
end # Grit
