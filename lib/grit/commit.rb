module Grit
  
  class Commit
    include Lazy
    
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
      
      __baked__
    end
    
    def id_abbrev
      @id_abbrev ||= @repo.git.rev_parse({:short => true}, self.id).chomp
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
      @repo = nil
      @id = nil
      @parents = nil
      @tree = nil
      @author = nil
      @authored_date = nil
      @committer = nil
      @committed_date = nil
      @message = nil
      @__baked__ = nil
      
      @repo = repo
      atts.each do |k, v|
        instance_variable_set("@#{k}".to_sym, v)
      end
      self
    end
    
    # Use the id of this instance to populate all of the other fields
    # when any of them are called.
    #
    # Returns nil
    def __bake__
      temp = self.class.find_all(@repo, @id, {:max_count => 1}).first
      @parents = temp.parents
      @tree = temp.tree
      @author = temp.author
      @authored_date = temp.authored_date
      @committer = temp.committer
      @committed_date = temp.committed_date
      @message = temp.message
      nil
    end
    
    # Count the number of commits reachable from this ref
    #   +repo+ is the Repo
    #   +ref+ is the ref from which to begin (SHA1 or name)
    #
    # Returns Integer
    def self.count(repo, ref)
      repo.git.rev_list({}, ref).strip.split("\n").size
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
      allowed_options = [:max_count, :skip, :since]
      
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
    
    # Show diffs between two trees:
    #   +repo+ is the Repo
    #   +a+ is a named commit
    #   +b+ is an optional named commit.  Passing an array assumes you 
    #     wish to omit the second named commit and limit the diff to the 
    #     given paths.
    #   +paths* is an array of paths to limit the diff.
    #
    # Returns Grit::Diff[] (baked)
    def self.diff(repo, a, b = nil, paths = [])
      if b.is_a?(Array)
        paths = b
        b     = nil
      end
      paths.unshift("--") unless paths.empty?
      paths.unshift(b)    unless b.nil?
      paths.unshift(a)
      text = repo.git.diff({:full_index => true}, *paths)
      Diff.list_from_string(repo, text)
    end

    def diffs
      if parents.empty?
        diff = @repo.git.show({:full_index => true, :pretty => 'raw'}, @id)
        if diff =~ /diff --git a/
          diff = diff.sub(/.+?(diff --git a)/m, '\1')
        else
          diff = ''
        end
        Diff.list_from_string(@repo, diff)
      else
        self.class.diff(@repo, parents.first.id, @id) 
      end
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
