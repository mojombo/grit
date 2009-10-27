module Grit

  class Merge

    STATUS_BOTH = 'both'
    STATUS_OURS = 'ours'
    STATUS_THEIRS = 'theirs'

    attr_reader :conflicts, :text, :sections

    def initialize(str)
      status = STATUS_BOTH

      section = 1
      @conflicts = 0
      @text = {}

      lines = str.split("\n")
      lines.each do |line|
        if /^<<<<<<< (.*?)/.match(line)
          status = STATUS_OURS
          @conflicts += 1
          section += 1
        elsif line == '======='
          status = STATUS_THEIRS
        elsif /^>>>>>>> (.*?)/.match(line)
          status = STATUS_BOTH
          section += 1
        else
          @text[section] ||= {}
          @text[section][status] ||= []
          @text[section][status] << line
        end
      end
      @text = @text.values
      @sections = @text.size
    end

    # Pretty object inspection
    def inspect
      %Q{#<Grit::Merge}
    end
  end # Merge

end # Grit
