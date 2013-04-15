module Grit

  class Grep
    
    attr_reader :repo
    attr_reader :filename
    attr_reader :line
    attr_reader :text
    attr_reader :is_binary

    def initialize(repo, filename, line, text, is_binary)
      @repo   = repo
      @filename = filename
      @line = line.to_i
      @text = text
      @is_binary = is_binary
    end
    
  end
  
end
