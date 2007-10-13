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
    #   +author+ is the 
    def initialize(repo, id, parents, tree, author, authored_date, committer, committed_date, message)
      @repo = repo
      @id = id
      @parents = parents
      @tree = tree
      @author = author
      @authored_date = authored_date
      @committer = committer
      @committed_date = committed_date
      @message = message
      
      __baked__
    end
    
    def self.create(repo, atts)
      self.allocate.create_initialize(repo, atts)
    end
    
    def create_initialize(repo, atts)
      @repo = repo
      atts.each do |k, v|
        instance_variable_set("@#{k}".to_sym, v)
      end
      self
    end
    
    # Use the id of this instance to populate all of the other fields
    # when any of them are called.
    def __bake__
      temp = self.class.find_all(@repo, @id, {:max_count => 1}).first
      @parents = temp.parents
      @tree = temp.tree
      @author = temp.author
      @authored_date = temp.authored_date
      @committer = temp.committer
      @committed_date = temp.committed_date
      @message = temp.message
    end
    
    # Find all commits matching the given criteria.
    #   +repo+ is the Repo
    #   +options+ is a Hash of optional arguments to git
    #     :max_count is the maximum number of commits to fetch
    #     :skip is the number of commits to skip
    #   +ref+ is the Ref from which to begin (
    def self.find_all(repo, ref, options = {})
      allowed_options = [:max_count, :skip]
      
      default_options = {:pretty => "raw"}
      actual_options = default_options.merge(options)
      
      output = repo.git.rev_list(actual_options, ref)
      
      self.list_from_string(repo, output)
    end
    
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
        messages << lines.shift.strip while lines.first =~ /^    /
        message = messages.first || ''
        
        commits << Commit.new(repo, id, parents, tree, author, authored_date, committer, committed_date, message)
      end
      
      commits
    end
    
    def to_s
      @id
    end
    
    # private
    
    def self.actor(line)
      m, actor, epoch = *line.match(/^.+? (.*) (\d+) .*$/)
      [actor, Time.at(epoch.to_i)]
    end
  end # Commit
  
end # Grit