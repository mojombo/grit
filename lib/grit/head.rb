module Grit
  
  class Head
    attr_accessor :id
    attr_accessor :name
    attr_accessor :message
    attr_accessor :committer
    attr_accessor :date
    
    def initialize(id, name, message, committer, date)
      self.id = id
      self.name = name
      self.message = message
      self.committer = committer
      self.date = date
    end
    
    # Create a new Head instance from the given string.
    #   +line+ is the formatted head information
    #
    # Format
    #   id: [0-9A-Fa-f]{40}
    #   <space>
    #   name: [^ ]*
    #   <space>
    #   message: [^\0]*
    #   <null byte>
    #   committer: .*
    #   <space>
    #   epoch: [0-9]+
    #   <space>
    #   tz: .*
    #
    # Returns Grit::Head
    def self.from_string(line)
      ref_info, committer_info = line.split("\0")
      id, name, message = ref_info.split(" ", 3)
      m, committer, epoch, tz = *committer_info.match(/^(.*) ([0-9]+) (.*)$/)
      date = Time.at(epoch.to_i)
      self.new(id, name, message, committer, date)
    end
  end # Head
  
end # Grit