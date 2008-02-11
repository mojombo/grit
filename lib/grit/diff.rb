module Grit
  
  class Diff
    attr_reader :a_path, :b_path
    attr_reader :a_commit, :b_commit
    attr_reader :mode
    attr_reader :new_file, :deleted_file
    attr_reader :diff
    
    def initialize(repo, a_path, b_path, a_commit, b_commit, mode, new_file, deleted_file, diff)
      @repo = repo
      @a_path = a_path
      @b_path = b_path
      @a_commit = a_commit =~ /^0{40}$/ ? nil : Commit.create(repo, :id => a_commit)
      @b_commit = b_commit =~ /^0{40}$/ ? nil : Commit.create(repo, :id => b_commit)
      @mode = mode
      @new_file = new_file
      @deleted_file = deleted_file
      @diff = diff
    end
    
    def self.list_from_string(repo, text)
      lines = text.split("\n")
      
      diffs = []
      
      while !lines.empty?
        m, a_path, b_path = *lines.shift.match(%r{^diff --git a/(\S+) b/(\S+)$})
        
        if lines.first =~ /^old mode/
          2.times { lines.shift }
        end
        
        new_file = false
        deleted_file = false
        
        if lines.first =~ /^new file/
          m, mode = lines.shift.match(/^new file mode (.+)$/)
          new_file = true
        elsif lines.first =~ /^deleted file/
          m, mode = lines.shift.match(/^deleted file mode (.+)$/)
          deleted_file = true
        end
        
        m, a_commit, b_commit, mode = *lines.shift.match(%r{^index ([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+) ?(.+)?$})
        mode.strip! if mode
        
        diff_lines = []
        while lines.first && lines.first !~ /^diff/
          diff_lines << lines.shift
        end
        diff = diff_lines.join("\n")
        
        diffs << Diff.new(repo, a_path, b_path, a_commit, b_commit, mode, new_file, deleted_file, diff)
      end
      
      diffs
    end
  end # Diff
  
end # Grit