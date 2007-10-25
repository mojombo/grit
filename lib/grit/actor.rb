module Grit
  
  class Actor
    attr_reader :name
    attr_reader :email
    
    def initialize(name, email)
      @name = name
      @email = email
    end
    
    def self.from_string(str)
      case str
        when /<.+>/
          m, name, email = *str.match(/(.*) <(.+?)>/)
          return self.new(name, email)
        else
          return self.new(str, nil)
      end
    end
  end # Actor
  
end # Grit