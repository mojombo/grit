module Grit

  class Blob
    DEFAULT_MIME_TYPE = "text/plain"

    attr_reader :id
    attr_reader :mode
    attr_reader :name

    # Create an unbaked Blob containing just the specified attributes
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Blob (unbaked)
    def self.create(repo, atts)
      self.allocate.create_initialize(repo, atts)
    end

    # Initializer for Blob.create
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Blob (unbaked)
    def create_initialize(repo, atts)
      @repo = repo
      atts.each do |k, v|
        instance_variable_set("@#{k}".to_sym, v)
      end
      self
    end

    # The size of this blob in bytes
    #
    # Returns Integer
    def size
      @size ||= @repo.git.cat_file({:s => true}, id).chomp.to_i
    end

    # The binary contents of this blob.
    #
    # Returns String
    def data
      @data ||= @repo.git.cat_file({:p => true}, id)
    end

    # The mime type of this file (based on the filename)
    #
    # Returns String
    def mime_type
      guesses = MIME::Types.type_for(self.name) rescue []
      guesses.first ? guesses.first.simplified : DEFAULT_MIME_TYPE
    end

    # The blame information for the given file at the given commit
    #
    # Returns Array: [Grit::Commit, Array: [<line>]]
    def self.blame(repo, commit, file)
      data = repo.git.blame({:p => true}, commit, '--', file)

      commits = {}
      blames = []
      info = nil

      data.split("\n").each do |line|
        parts = line.split(/\s+/, 2)
        case parts.first
          when /^[0-9A-Fa-f]{40}$/
            case line
              when /^([0-9A-Fa-f]{40}) (\d+) (\d+) (\d+)$/
                _, id, origin_line, final_line, group_lines = *line.match(/^([0-9A-Fa-f]{40}) (\d+) (\d+) (\d+)$/)
                info = {:id => id}
                blames << [nil, []]
              when /^([0-9A-Fa-f]{40}) (\d+) (\d+)$/
                _, id, origin_line, final_line = *line.match(/^([0-9A-Fa-f]{40}) (\d+) (\d+)$/)
                info = {:id => id}
            end
          when /^(author|committer)/
            case parts.first
              when /^(.+)-mail$/
                info["#{$1}_email".intern] = parts.last
              when /^(.+)-time$/
                info["#{$1}_date".intern] = Time.at(parts.last.to_i)
              when /^(author|committer)$/
                info[$1.intern] = parts.last
            end
          when /^filename/
            info[:filename] = parts.last
          when /^summary/
            info[:summary] = parts.last
          when ''
            c = commits[info[:id]]
            unless c
              c = Commit.create(repo, :id => info[:id],
                                      :author => Actor.from_string(info[:author] + ' ' + info[:author_email]),
                                      :authored_date => info[:author_date],
                                      :committer => Actor.from_string(info[:committer] + ' ' + info[:committer_email]),
                                      :committed_date => info[:committer_date],
                                      :message => info[:summary])
              commits[info[:id]] = c
            end
            _, text = *line.match(/^\t(.*)$/)
            blames.last[0] = c
            blames.last[1] << text
            info = nil
        end
      end

      blames
    end

    def basename
      File.basename(name)
    end

    # Pretty object inspection
    def inspect
      %Q{#<Grit::Blob "#{@id}">}
    end

    # Compares blobs by name
    def <=>(other)
      name <=> other.name
    end
  end # Blob

end # Grit