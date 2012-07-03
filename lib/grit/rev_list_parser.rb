module Grit
  class RevListParser
    class Entry
      attr_reader :meta, :message_lines

      def initialize
        @done = false
        @meta = {}
        @message_lines = []
      end

      def parse(line)
        spaces = line.scan(/^ */).first
        if spaces.size >= 4
          parse_message(line)
        else
          parse_meta(line, spaces.size)
        end
      end

      def parse_meta(line, spaces)
        return if spaces > 0
        header, value = line.split(' ', 2)
        values = @meta[header] ||= []
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
      entry = nil
      while !lines.empty?
        line = lines.shift
        entry = current_entry(entry, line)
        entry.parse(line)
      end
    end

    def current_entry(entry, line)
      if entry && entry.message? && line.empty?
        entry = nil
      end

      if !entry
        @entries << (entry = Entry.new)
      end
      entry
    end
  end
end
