module Grit
  
  class Tree
    include Lazy
    
    lazy_reader :contents
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
    def self.construct(repo, treeish, paths = [])
      output = repo.git.ls_tree({}, treeish, paths.join(" "))
      
      self.allocate.construct_initialize(repo, treeish, output)
    end
    
    def construct_initialize(repo, id, text)
      @repo = repo
      @id = id
      @contents = []
      text.split("\n").each do |line|
        @contents << content_from_string(repo, line)
      end
      __baked__
      self
    end
    
    def __bake__
      temp = Tree.construct(@repo, @id, [])
      @contents = temp.contents
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
    
    # Parse a content item and create the appropriate object
    #   +repo+ is the Repo
    #   +text+ is the single line containing the items data in `git ls-tree` format
    #
    # Returns Grit::Blob or Grit::Tree
    def content_from_string(repo, text)
      mode, type, id, name = text.split(" ", 4)
      case type
        when "tree"
          Tree.create(repo, :id => id, :mode => mode, :name => name)
        when "blob"
          Blob.create(repo, :id => id, :mode => mode, :name => name)
        when "commit"
          nil
        else
          raise "Invalid type: #{type}"
      end
    end
    
    # Pretty object inspection
    def inspect
      %Q{#<Grit::Tree "#{@id}">}
    end
  end # Tree
  
end # Grit