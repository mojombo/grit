module Grit

  class Diff
    attr_reader :a_path, :b_path
    attr_reader :a_blob, :b_blob
    attr_reader :a_mode, :b_mode
    attr_reader :new_file, :deleted_file, :renamed_file
    attr_reader :similarity_index
    attr_accessor :diff

    def initialize(repo, a_path, b_path, a_blob, b_blob, a_mode, b_mode, new_file, deleted_file, diff, renamed_file = false, similarity_index = 0)
      @repo   = repo
      @a_path = a_path
      @b_path = b_path
      @a_blob = a_blob =~ /^0{40}$/ ? nil : Blob.create(repo, :id => a_blob)
      @b_blob = b_blob =~ /^0{40}$/ ? nil : Blob.create(repo, :id => b_blob)
      @a_mode = a_mode
      @b_mode = b_mode
      @new_file         = new_file     || @a_blob.nil?
      @deleted_file     = deleted_file || @b_blob.nil?
      @renamed_file     = renamed_file
      @similarity_index = similarity_index.to_i
      @diff             = diff
    end

    def self.list_from_string(repo, text)
      lines = text.split("\n")

      diffs = []

      while !lines.empty?
        m, a_path, b_path = *lines.shift.match(%r{^diff --git a/(.+?) b/(.+)$})

        if lines.first =~ /^old mode/
          m, a_mode = *lines.shift.match(/^old mode (\d+)/)
          m, b_mode = *lines.shift.match(/^new mode (\d+)/)
        end

        if lines.empty? || lines.first =~ /^diff --git/
          diffs << Diff.new(repo, a_path, b_path, nil, nil, a_mode, b_mode, false, false, nil)
          next
        end

        sim_index    = 0
        new_file     = false
        deleted_file = false
        renamed_file = false

        if lines.first =~ /^new file/
          m, b_mode = lines.shift.match(/^new file mode (.+)$/)
          a_mode    = nil
          new_file  = true
        elsif lines.first =~ /^deleted file/
          m, a_mode    = lines.shift.match(/^deleted file mode (.+)$/)
          b_mode       = nil
          deleted_file = true
        elsif lines.first =~ /^similarity index (\d+)\%/
          sim_index    = $1.to_i
          renamed_file = true
          2.times { lines.shift } # shift away the 2 `rename from/to ...` lines
        end

        m, a_blob, b_blob, b_mode = *lines.shift.match(%r{^index ([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+) ?(.+)?$})
        b_mode.strip! if b_mode

        diff_lines = []
        while lines.first && lines.first !~ /^diff/
          diff_lines << lines.shift
        end
        diff = diff_lines.join("\n")

        diffs << Diff.new(repo, a_path, b_path, a_blob, b_blob, a_mode, b_mode, new_file, deleted_file, diff, renamed_file, sim_index)
      end

      diffs
    end
  end # Diff

end # Grit
