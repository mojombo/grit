module Grit
  
  class Tag
    attr_reader :name
    attr_reader :commit
    
    # Instantiate a new Tag
    #   +name+ is the name of the head
    #   +commit+ is the Commit that the head points to
    #
    # Returns Grit::Tag (baked)
    def initialize(name, commit)
      @name = name
      @commit = commit
    end
    
    # Find all Tags
    #   +repo+ is the Repo
    #   +options+ is a Hash of options
    #
    # Returns Grit::Tag[] (baked)
    def self.find_all(repo, options = {})
      default_options = {:sort => "committerdate",
                         :format => "%(refname)%00%(objectname)"}
                         
      actual_options = default_options.merge(options)
      
      output = repo.git.for_each_ref(actual_options, "refs/tags")
                 
      self.list_from_string(repo, output)
    end
    
    # Parse out tag information into an array of baked Tag objects
    #   +repo+ is the Repo
    #   +text+ is the text output from the git command
    #
    # Returns Grit::Tag[] (baked)
    def self.list_from_string(repo, text)
      tags = []
      
      text.split("\n").each do |line|
        tags << self.from_string(repo, line)
      end
      
      tags
    end
    
    # Create a new Tag instance from the given string.
    #   +repo+ is the Repo
    #   +line+ is the formatted tag information
    #
    # Format
    #   name: [a-zA-Z_/]+
    #   <null byte>
    #   id: [0-9A-Fa-f]{40}
    #
    # Returns Grit::Tag (baked)
    def self.from_string(repo, line)
      full_name, id = line.split("\0")
      name = full_name.split("/").last
      commit = Commit.create(repo, :id => id)
      self.new(name, commit)
    end
    
    # Pretty object inspection
    def inspect
      %Q{#<Grit::Tag "#{@name}">}
    end
  end # Tag
  
end # Grit