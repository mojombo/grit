module Grit

  class Blame

    attr_reader :lines

    def initialize(repo, file, commit)
      @repo = repo
      @file = file
      @commit = commit
      @lines = []
      load_blame
    end

    def load_blame
      output = @repo.git.blame({'p' => true}, @commit, '--', @file)
      process_raw_blame(output)
    end

    def process_raw_blame(output)
      lines, final = [], []
      info, commits = {}, {}

      # process the output
      output.split("\n").each do |line|
        if line[0, 1] == "\t"
          lines << line[1, line.size]
        elsif m = /^(\w{40}) (\d+) (\d+)/.match(line)
          if !commits[m[1]]
            commits[m[1]] = @repo.commit(m[1])
          end
          info[m[3].to_i] = [commits[m[1]], m[2].to_i]
        end
      end

      # get it together
      info.sort.each do |lineno, commit|
        final << BlameLine.new(lineno, commit[1], commit[0], lines[lineno - 1])
      end

      @lines = final
    end

    # Pretty object inspection
    def inspect
      %Q{#<Grit::Blame "#{@file} <#{@commit}>">}
    end

    class BlameLine
      attr_accessor :lineno, :oldlineno, :commit, :line
      def initialize(lineno, oldlineno, commit, line)
        @lineno = lineno
        @oldlineno = oldlineno
        @commit = commit
        @line = line
      end
    end

  end # Blame

end # Grit