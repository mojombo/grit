module Grit

  class Blame

    attr_reader :lines

    def initialize(repo, file, commit, lines=nil)
      @repo = repo
      @file = file
      @commit = commit
      if lines.nil?
        @lines = []
        load_blame
      else
        @lines = lines
      end
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
          commit_id, old_lineno, lineno = m[1], m[2].to_i, m[3].to_i
          commits[commit_id] = nil if !commits.key?(commit_id)
          info[lineno] = [commit_id, old_lineno]
        end
      end

      # load all commits in single call
      @repo.batch(*commits.keys).each do |commit|
        commits[commit.id] = commit
      end

      # get it together
      info.sort.each do |lineno, (commit_id, old_lineno)|
        commit = commits[commit_id]
        final << BlameLine.new(lineno, old_lineno, commit, lines[lineno - 1])
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
