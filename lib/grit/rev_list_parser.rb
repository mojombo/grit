module Grit
  class RevListParser
    class Entry
      attr_reader :meta, :message_lines

      def initialize
        @finished_meta = false
        @meta = {}
        @message_lines = []
      end

      def commit
        @meta[:commit].to_s
      end

      def parents
        @meta[:parent] || []
      end

      def tree
        @meta[:tree].to_s
      end

      def author
        @meta[:author].to_s
      end

      def committer
        @meta[:committer].to_s
      end

      def parse(line)
        if line.empty?
          # 2 blank lines after meta data means no commit message
          return if @finished_meta

          # if this is our first blank line, lets get the message
          return @finished_meta = true
        end

        spaces = line.scan(/^ */).first

        if @finished_meta
          # messages should be prefixed by at least 4 spaces.  Otherwise we
          # may be in the next commit.
          return if spaces.size < 4
          parse_message(line)
        else
          parse_meta(line, spaces.size)
        end
        true
      end

      def parse_meta(line, spaces)
        return if spaces > 0 || line.empty?
        header, value = line.split(' ', 2)
        values = @meta[header.to_sym] ||= []
        values << value
      end

      def parse_message(line)
        @message_lines << line[4..-1]
      end

      def message?
        @message_lines.size > 0
      end
    end

    attr_reader :entries

    def initialize(text)
      @entries = []
      lines = text.split("\n")
      @entry = nil
      while !lines.empty?
        parse_line(lines.shift)
      end
    end

    def parse_line(line)
      if @entry && !@entry.parse(line)
        @entry = nil
      end

      if !@entry && !line.empty?
        @entries << (@entry = Entry.new)
        @entry.parse(line)
      end
    end
  end
end
