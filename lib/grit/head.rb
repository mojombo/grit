module Grit
  
  # A Head is a named reference to a Commit. Every Head instance contains a name
  # and a Commit object.
  #
  #   r = Grit::Repo.new("/path/to/repo")
  #   h = r.heads.first
  #   h.name       # => "master"
  #   h.commit     # => #<Grit::Commit "1c09f116cbc2cb4100fb6935bb162daa4723f455">
  #   h.commit.id  # => "1c09f116cbc2cb4100fb6935bb162daa4723f455"
  class Head
    attr_reader :name
    attr_reader :commit
    
    # Instantiate a new Head
    #   +name+ is the name of the head
    #   +commit+ is the Commit that the head points to
    #
    # Returns Grit::Head (baked)
    def initialize(name, commit)
      @name = name
      @commit = commit
    end
    
    # Find all Heads
    #   +repo+ is the Repo
    #   +options+ is a Hash of options
    #
    # Returns Grit::Head[] (baked)
    def self.find_all(repo, options = {})
      default_options = {:sort => "committerdate",
                         :format => "%(refname)%00%(objectname)"}
                         
      actual_options = default_options.merge(options)
      
      output = repo.git.for_each_ref(actual_options, "refs/heads")
                 
      Head.list_from_string(repo, output)
    end
    
    # Parse out head information into an array of baked head objects
    #   +repo+ is the Repo
    #   +text+ is the text output from the git command
    #
    # Returns Grit::Head[] (baked)
    def self.list_from_string(repo, text)
      heads = []
      
      text.split("\n").each do |line|
        heads << self.from_string(repo, line)
      end
      
      heads
    end
    
    # Create a new Head instance from the given string.
    #   +repo+ is the Repo
    #   +line+ is the formatted head information
    #
    # Format
    #   name: [a-zA-Z_/]+
    #   <null byte>
    #   id: [0-9A-Fa-f]{40}
    #
    # Returns Grit::Head (baked)
    def self.from_string(repo, line)
      full_name, id = line.split("\0")
      name = full_name.split("/").last
      commit = Commit.create(repo, :id => id)
      self.new(name, commit)
    end
    
    # Pretty object inspection
    def inspect
      %Q{#<Grit::Head "#{@name}">}
    end
  end # Head
  
end # Grit