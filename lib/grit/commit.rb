module Grit
  
  class Commit
    attr_reader :id
    attr_reader :parents
    attr_reader :tree
    attr_reader :author
    attr_reader :authored_date
    attr_reader :committer
    attr_reader :committed_date
    attr_reader :message
    
    # Instantiate a new Commit
    #   +id+ is the id of the commit
    #   +parents+ is an array of commit ids (will be converted into Commit instances)
    #   +tree+ is the correspdonding tree id (will be converted into a Tree object)
    #   +author+ is the 
    def initialize(id, parents, tree, author, authored_date, committer, committed_date, message)
      @id = id
      @parents = parents
      @tree = tree
      @author = author
      @authored_date = authored_date
      @committer = committer
      @committed_date = committed_date
      @message = message
    end
    
    def self.list_from_string(text)
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
        
        commits << Commit.new(id, parents, tree, author, authored_date, committer, committed_date, message)
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