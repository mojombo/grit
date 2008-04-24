module Grit

  class Ref

    class << self

      # Find all Refs
      #   +repo+ is the Repo
      #   +options+ is a Hash of options
      #
      # Returns Grit::Ref[] (baked)
      def find_all(repo, options = {})
        default_options = {:sort => "committerdate",
                           :format => "%(refname)%00%(objectname)"}

        actual_options = default_options.merge(options)

        output = repo.git.for_each_ref(actual_options, prefix)

        self.list_from_string(repo, output)
      end

      # Parse out ref information into an array of baked refs objects
      #   +repo+ is the Repo
      #   +text+ is the text output from the git command
      #
      # Returns Grit::Ref[] (baked)
      def list_from_string(repo, text)
        refs = []

        text.split("\n").each do |line|
          refs << self.from_string(repo, line)
        end

        refs.sort { | x, y | x.name <=> y.name }
      end

      # Create a new Ref instance from the given string.
      #   +repo+ is the Repo
      #   +line+ is the formatted head information
      #
      # Format
      #   name: [a-zA-Z_/]+
      #   <null byte>
      #   id: [0-9A-Fa-f]{40}
      #
      # Returns Grit::Ref (baked)
      def from_string(repo, line)
        full_name, id = line.split("\0")
        name = full_name.sub("#{prefix}/", '')
        commit = Commit.create(repo, :id => id)
        self.new(name, commit)
      end

      protected

        def prefix
          "refs/#{name.to_s.gsub(/^.*::/, '').downcase}s"
        end

    end

    attr_reader :name
    attr_reader :commit

    # Instantiate a new Head
    #   +name+ is the name of the head
    #   +commit+ is the Commit that the head points to
    #
    # Returns Grit::Head (baked)
    def initialize(name, commit)
      @name = name
      @commit = commit
    end

    # Pretty object inspection
    def inspect
      %Q{#<#{self.class.name} "#{@name}">}
    end
  end # Ref

  # A Head is a named reference to a Commit. Every Head instance contains a name
  # and a Commit object.
  #
  #   r = Grit::Repo.new("/path/to/repo")
  #   h = r.heads.first
  #   h.name       # => "master"
  #   h.commit     # => #<Grit::Commit "1c09f116cbc2cb4100fb6935bb162daa4723f455">
  #   h.commit.id  # => "1c09f116cbc2cb4100fb6935bb162daa4723f455"
  class Head < Ref

    # Get the HEAD revision of the repo.
    #   +repo+ is the Repo
    #   +options+ is a Hash of options
    #
    # Returns Grit::Head (baked)
    def self.current(repo, options = {})
      head = File.open(File.join(repo.path, 'HEAD')).read.chomp
      if /ref: refs\/heads\/(.*)/.match(head)
        self.new($1, repo.git.rev_parse(options, 'HEAD'))
      end
    end

  end # Head

  class Tag < Ref ; end

  class Remote < Ref ; end

end # Grit
