module Grit
  
  class Tree
    attr_reader :contents
    attr_reader :id
    attr_reader :mode
    attr_reader :name
    
    def initialize
      
    end
    
    # Construct the contents of the tree
    #   +repo+ is the Repo
    #   +treeish+ is the reference
    #   +paths+ is an optional Array of directory paths to restrict the tree
    #
    # Returns Grit::Tree (baked)
    def self.construct(repo, treeish, paths)
      output = repo.git.ls_tree({}, treeish, paths.join(" "))
      
      self.allocate.construct_initialize(repo, output)
    end
    
    def construct_initialize(repo, text)
      @repo = repo
      @contents = []
      text.split("\n").each do |line|
        @contents << content_from_string(repo, line)
      end
      self
    end
    
    # Create an unbaked Tree containing just the specified attributes
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Tree (unbaked)
    def self.create(repo, atts)
      self.allocate.create_initialize(repo, atts)
    end
    
    # Initializer for Tree.create
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Tree (unbaked)
    def create_initialize(repo, atts)
      @repo = repo
      atts.each do |k, v|
        instance_variable_set("@#{k}".to_sym, v)
      end
      self
    end
    
    def content_from_string(repo, text)
      mode, type, id, name = text.split(" ", 4)
      case type
        when "tree"
          Tree.create(repo, :id => id, :mode => mode, :name => name)
        when "blob"
          nil
        else
          raise "Invalid type: #{type}"
      end
    end
  end # Tree
  
end # Grit