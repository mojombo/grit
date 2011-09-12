module Grit

  class Diff
    attr_reader :a_path, :b_path
    attr_reader :a_path2, :b_path2
    attr_reader :a_blob, :b_blob
    attr_reader :a_mode, :b_mode
    attr_reader :new_file, :deleted_file, :renamed_file
    attr_reader :similarity_index
    attr_reader :hunks

    def initialize(repo, a_path, a_path2, b_path, b_path2, a_blob, b_blob, a_mode, b_mode, new_file, deleted_file, hunks = [], renamed_file = false, similarity_index = 0)
      @repo   = repo
      @a_path = a_path
      @a_path2 = a_path2
      @b_path = b_path
      @b_path2 = b_path2
      @a_blob = a_blob =~ /^0{40}$/ ? nil : Blob.create(repo, :id => a_blob)
      @b_blob = b_blob =~ /^0{40}$/ ? nil : Blob.create(repo, :id => b_blob)
      @a_mode = a_mode
      @b_mode = b_mode
      @new_file         = new_file     || @a_blob.nil?
      @deleted_file     = deleted_file || @b_blob.nil?
      @renamed_file     = renamed_file
      @similarity_index = similarity_index.to_i
      @hunks             = hunks
    end
    
    def diff
      return '' if @hunks.empty?
      
      output = ''
      output << "--- #{a_path2}\n"
      output << "+++ #{b_path2}\n"
      output << @hunks.map(&:diff_output).join("\n")
      output
    end

    def self.list_from_string(repo, text)
      lines = text.split("\n")

      diffs = []

      while !lines.empty?
        a_mode = b_mode = nil
        a_blob = b_blob = nil
        m, a_path, b_path = *lines.shift.match(%r{^diff --git a/(.+?) b/(.+)$})

        if lines.first =~ /^old mode/
          m, a_mode = *lines.shift.match(/^old mode (\d+)/)
          m, b_mode = *lines.shift.match(/^new mode (\d+)/)
        end

        sim_index    = 0
        new_file     = false
        deleted_file = false
        renamed_file = false

        if lines.first =~ /^new file/
          m, b_mode = lines.shift.match(/^new file mode (.+)$/)
          new_file  = true
        elsif lines.first =~ /^deleted file/
          m, a_mode    = lines.shift.match(/^deleted file mode (.+)$/)
          deleted_file = true
        elsif lines.first =~ /^similarity index (\d+)\%/
          sim_index    = $1.to_i
          renamed_file = true
          3.times { lines.shift } # shift away the similarity line and the 2 `rename from/to ...` lines
        end

        if lines.first =~ /^index /
          m, a_blob, b_blob, b_mode = *lines.shift.match(%r{^index ([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+) ?(.+)?$})
          b_mode.strip! if b_mode
          a_mode = b_mode
        else
          a_blob = b_blob = nil
        end

        if lines.first =~ /^--- /
          a_path2 = lines.shift[4..-1]
        else
          a_path2 = nil
        end
        if lines.first =~ /^\+\+\+ /
          b_path2 = lines.shift[4..-1]
        else
          a_path2 = b_path2 = nil
        end

        hunks = []
        while lines.first && lines.first[0, 3] == '@@ '
          m, a_line_data, b_line_data, context = *lines.shift.match(/^@@ -(\S+) \+(\S+) @@(.*)$/)
          a_first_line, a_lines = *a_line_data.split(',')
          b_first_line, b_lines = *b_line_data.split(',')
          context = (context.length <= 1) ? nil : context[1..-1]
          
          hunk_lines = []
          while lines.first && ![?d, ?@].include?(lines.first[0])
            hunk_lines << lines.shift
          end
          diff = hunk_lines.join("\n")
          hunks << Hunk.new(a_first_line, a_lines, b_first_line, b_lines, context, diff)
        end

        diffs << Diff.new(repo, a_path, a_path2, b_path, b_path2, a_blob, b_blob, a_mode, b_mode, new_file, deleted_file, hunks, renamed_file, sim_index)
      end

      diffs
    end
    
    class Hunk
      attr_reader :a_first_line, :a_lines, :b_first_line, :b_lines, :context, :diff
      
      def initialize(a_first_line, a_lines, b_first_line, b_lines, context, diff)
        @a_first_line = a_first_line.to_i
        @a_lines = a_lines && a_lines.to_i
        @b_first_line = b_first_line.to_i
        @b_lines = b_lines && b_lines.to_i
        @context = context
        @diff = diff
      end
      
      def diff_output
        output = "@@ "
        output << "-#{a_first_line}"
        output << ",#{a_lines}" if a_lines
        output << " +#{b_first_line}"
        output << ",#{b_lines}" if b_lines
        output << " @@"
        output << " #{context}" if context
        output << "\n"
        output << @diff
        output
      end
    end # Hunk
  end # Diff

end # Grit
