module Grit
  
  class Blob
    attr_reader :id
    attr_reader :mode
    attr_reader :name
    
    # Create an unbaked Blob containing just the specified attributes
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Blob (unbaked)
    def self.create(repo, atts)
      self.allocate.create_initialize(repo, atts)
    end
    
    # Initializer for Blob.create
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Blob (unbaked)
    def create_initialize(repo, atts)
      @repo = repo
      atts.each do |k, v|
        instance_variable_set("@#{k}".to_sym, v)
      end
      self
    end
    
    # The size of this blob in bytes
    #
    # Returns Integer
    def size
      @size ||= @repo.git.cat_file({:s => true}, id).chomp.to_i
    end
    
    # The binary contents of this blob.
    #
    # Returns String
    def data
      @data ||= @repo.git.cat_file({:p => true}, id)
    end
    
    # Pretty object inspection
    def inspect
      %Q{#<Grit::Blob "#{@id}">}
    end
  end # Blob
  
end # Grit