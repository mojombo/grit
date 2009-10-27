#
# converted from the gitrb project
#
# authors:
#    Matthias Lederhofer <matled@gmx.net>
#    Simon 'corecode' Schubert <corecode@fs.ei.tum.de>
#    Scott Chacon <schacon@gmail.com>
#
# provides native ruby access to git objects and pack files
#

# These classes translate the raw binary data kept in the sha encoded files
# into parsed data that can then be used in another fashion
require 'stringio'

module Grit
  module GitRuby

  # class for author/committer/tagger lines
  class UserInfo
    attr_accessor :name, :email, :date, :offset

    def initialize(str)
      m = /^(.*?) <(.*)> (\d+) ([+-])0*(\d+?)$/.match(str)
      if !m
        raise RuntimeError, "invalid header '%s' in commit" % str
      end
      @name = m[1]
      @email = m[2]
      @date = Time.at(Integer(m[3]))
      @offset = (m[4] == "-" ? -1 : 1)*Integer(m[5])
    end

    def to_s
      "%s <%s> %s %+05d" % [@name, @email, @date.to_i, @offset]
    end
  end

  # base class for all git objects (blob, tree, commit, tag)
  class Object
    attr_accessor :repository

    def Object.from_raw(rawobject, repository = nil)
      case rawobject.type
      when :blob
        return Blob.from_raw(rawobject, repository)
      when :tree
        return Tree.from_raw(rawobject, repository)
      when :commit
        return Commit.from_raw(rawobject, repository)
      when :tag
        return Tag.from_raw(rawobject, repository)
      else
        raise RuntimeError, "got invalid object-type"
      end
    end

    def initialize
      raise NotImplemented, "abstract class"
    end

    def type
      raise NotImplemented, "abstract class"
    end

    def raw_content
      raise NotImplemented, "abstract class"
    end

    def sha1
      Digest::SHA1.hexdigest("%s %d\0" % \
                             [self.type, self.raw_content.length] + \
                             self.raw_content)
    end
  end

  class Blob < Object
    attr_accessor :content

    def self.from_raw(rawobject, repository)
      new(rawobject.content)
    end

    def initialize(content, repository=nil)
      @content = content
      @repository = repository
    end

    def type
      :blob
    end

    def raw_content
      @content
    end
  end

  class DirectoryEntry
    S_IFMT  = 00170000
    S_IFLNK =  0120000
    S_IFREG =  0100000
    S_IFDIR =  0040000

    attr_accessor :mode, :name, :sha1
    def initialize(mode, filename, sha1o)
      @mode = 0
      mode.each_byte do |i|
        @mode = (@mode << 3) | (i-'0'[0])
      end
      @name = filename
      @sha1 = sha1o
      if ![S_IFLNK, S_IFDIR, S_IFREG].include?(@mode & S_IFMT)
        raise RuntimeError, "unknown type for directory entry"
      end
    end

    def type
      case @mode & S_IFMT
      when S_IFLNK
        @type = :link
      when S_IFDIR
        @type = :directory
      when S_IFREG
        @type = :file
      else
        raise RuntimeError, "unknown type for directory entry"
      end
    end

    def type=(type)
      case @type
      when :link
        @mode = (@mode & ~S_IFMT) | S_IFLNK
      when :directory
        @mode = (@mode & ~S_IFMT) | S_IFDIR
      when :file
        @mode = (@mode & ~S_IFMT) | S_IFREG
      else
        raise RuntimeError, "invalid type"
      end
    end

    def format_type
      case type
      when :link
        'link'
      when :directory
        'tree'
      when :file
        'blob'
      end
    end

    def format_mode
      "%06o" % @mode
    end

    def raw
      "%o %s\0%s" % [@mode, @name, [@sha1].pack("H*")]
    end
  end


  def self.read_bytes_until(io, char)
    string = ''
    if RUBY_VERSION > '1.9'
      while ((next_char = io.getc) != char) && !io.eof
        string += next_char
      end
    else
      while ((next_char = io.getc.chr) != char) && !io.eof
        string += next_char
      end
    end
    string
  end


  class Tree < Object
    attr_accessor :entry

    def self.from_raw(rawobject, repository=nil)
      raw = StringIO.new(rawobject.content)

      entries = []
      while !raw.eof?
        mode      = Grit::GitRuby.read_bytes_until(raw, ' ')
        file_name = Grit::GitRuby.read_bytes_until(raw, "\0")
        raw_sha   = raw.read(20)
        sha = raw_sha.unpack("H*").first

        entries << DirectoryEntry.new(mode, file_name, sha)
      end
      new(entries, repository)
    end

    def initialize(entries=[], repository = nil)
      @entry = entries
      @repository = repository
    end

    def type
      :tree
    end

    def raw_content
      # TODO: sort correctly
      #@entry.sort { |a,b| a.name <=> b.name }.
      @entry.collect { |e| [[e.format_mode, e.format_type, e.sha1].join(' '), e.name].join("\t") }.join("\n")
    end

    def actual_raw
      #@entry.collect { |e| e.raw.join(' '), e.name].join("\t") }.join("\n")
    end
  end

  class Commit < Object
    attr_accessor :author, :committer, :tree, :parent, :message, :headers

    def self.from_raw(rawobject, repository=nil)
      parent = []
      tree = author = committer = nil

      headers, message = rawobject.content.split(/\n\n/, 2)
      all_headers = headers.split(/\n/).map { |header| header.split(/ /, 2) }
      all_headers.each do |key, value|
        case key
        when "tree"
          tree = value
        when "parent"
          parent.push(value)
        when "author"
          author = UserInfo.new(value)
        when "committer"
          committer = UserInfo.new(value)
        else
          warn "unknown header '%s' in commit %s" % \
            [key, rawobject.sha1.unpack("H*")[0]]
        end
      end
      if not tree && author && committer
        raise RuntimeError, "incomplete raw commit object"
      end
      new(tree, parent, author, committer, message, headers, repository)
    end

    def initialize(tree, parent, author, committer, message, headers, repository=nil)
      @tree = tree
      @author = author
      @parent = parent
      @committer = committer
      @message = message
      @headers = headers
      @repository = repository
    end

    def type
      :commit
    end

    def raw_content
      "tree %s\n%sauthor %s\ncommitter %s\n\n" % [
        @tree,
        @parent.collect { |i| "parent %s\n" % i }.join,
        @author, @committer] + @message
    end

    def raw_log(sha)
      output = "commit #{sha}\n"
      output += @headers + "\n\n"
      output += @message.split("\n").map { |l| '    ' + l }.join("\n") + "\n\n"
    end

  end

  class Tag < Object
    attr_accessor :object, :type, :tag, :tagger, :message

    def self.from_raw(rawobject, repository=nil)
      headers, message = rawobject.content.split(/\n\n/, 2)
      headers = headers.split(/\n/).map { |header| header.split(/ /, 2) }
      headers.each do |key, value|
        case key
        when "object"
          object = value
        when "type"
          if !["blob", "tree", "commit", "tag"].include?(value)
            raise RuntimeError, "invalid type in tag"
          end
          type = value.to_sym
        when "tag"
          tag = value
        when "tagger"
          tagger = UserInfo.new(value)
        else
          warn "unknown header '%s' in tag" % \
            [key, rawobject.sha1.unpack("H*")[0]]
        end
        if not object && type && tag && tagger
          raise RuntimeError, "incomplete raw tag object"
        end
      end
      new(object, type, tag, tagger, repository)
    end

    def initialize(object, type, tag, tagger, repository=nil)
      @object = object
      @type = type
      @tag = tag
      @tagger = tagger
      @repository = repository
    end

    def raw_content
      "object %s\ntype %s\ntag %s\ntagger %s\n\n" % \
        [@object, @type, @tag, @tagger] + @message
    end

    def type
      :tag
    end
  end

  end
end
