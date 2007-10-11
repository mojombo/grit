module Grit
  
  class Commit
    attr_accessor :id
    attr_accessor :parents
    attr_accessor :tree
    attr_accessor :author
    attr_accessor :authored_date
    attr_accessor :committer
    attr_accessor :committed_date
    attr_accessor :message
    
    def initialize(id, parents, tree, author, authored_date, committer, committed_date, message)
      self.id = id
      self.parents = parents
      self.tree = tree
      self.author = author
      self.authored_date = authored_date
      self.committer = committer
      self.committed_date = committed_date
      self.message = message
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
    
    # private
    
    def self.actor(line)
      m, actor, epoch = *line.match(/^.+? (.*) (\d+) .*$/)
      [actor, Time.at(epoch.to_i)]
    end
  end # Commit
  
end # Grit