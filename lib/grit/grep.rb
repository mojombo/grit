module Grit

  class Grep
    
    attr_reader :repo
    attr_reader :filename
    attr_reader :startline
    attr_reader :content
    attr_reader :is_binary

    def initialize(repo, filename, startline, content, is_binary)
      @repo   = repo
      @filename = filename
      @startline = startline.to_i
      @content = content
      @is_binary = is_binary
    end
    
  end
  
end
