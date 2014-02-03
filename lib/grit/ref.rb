module Grit

  class Ref

    class << self

      # Count all Refs
      #   +repo+ is the Repo
      #   +options+ is a Hash of options
      #
      # Returns int
      def count_all(repo, options = {})
        refs = repo.git.refs(options, prefix)
        refs.split("\n").size
      end

      # Find all Refs
      #   +repo+ is the Repo
      #   +options+ is a Hash of options
      #
      # Returns Grit::Ref[] (baked)
      def find_all(repo, options = {})
        refs = repo.git.refs(options, prefix)
        refs.split("\n").map do |ref|
          name, id = *ref.split(' ')
          self.new(name, repo, id)
        end
      end

      protected

        def prefix
          "refs/#{name.to_s.gsub(/^.*::/, '').downcase}s"
        end

    end

    attr_reader :name

    # Instantiate a new Head
    #   +name+ is the name of the head
    #   +commit+ is the Commit that the head points to
    #
    # Returns Grit::Head (baked)
    def initialize(name, repo, commit_id)
      @name = name
      @commit_id = commit_id
      @repo_ref = repo
      @commit = nil
    end

    def commit
      @commit ||= get_commit
    end

    # Pretty object inspection
    def inspect
      %Q{#<#{self.class.name} "#{@name}">}
    end

    protected

    def get_commit
      Commit.create(@repo_ref, :id => @commit_id)
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
      head = repo.git.fs_read('HEAD').chomp
      if /ref: refs\/heads\/(.*)/.match(head)
        id = repo.git.rev_parse(options, 'HEAD')
        self.new($1, repo, id)
      end
    end

  end # Head

  class Remote < Ref; end

  class Note < Ref; end

end # Grit
