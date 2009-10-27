module Grit

  class Actor
    attr_reader :name
    attr_reader :email

    def initialize(name, email)
      @name = name
      @email = email
    end
    alias_method :to_s, :name

    # Create an Actor from a string.
    #   +str+ is the string, which is expected to be in regular git format
    #
    # Format
    #   John Doe <jdoe@example.com>
    #
    # Returns Actor
    def self.from_string(str)
      case str
        when /<.+>/
          m, name, email = *str.match(/(.*) <(.+?)>/)
          return self.new(name, email)
        else
          return self.new(str, nil)
      end
    end

    # Pretty object inspection
    def inspect
      %Q{#<Grit::Actor "#{@name} <#{@email}>">}
    end
  end # Actor

end # Grit
