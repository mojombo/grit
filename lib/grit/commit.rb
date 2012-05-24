module Grit

  class Commit
    extend Lazy

    attr_reader :id
    attr_reader :repo
    lazy_reader :parents
    lazy_reader :tree
    lazy_reader :author
    lazy_reader :authored_date
    lazy_reader :committer
    lazy_reader :committed_date
    lazy_reader :message
    lazy_reader :short_message

    # Parses output from the `git-cat-file --batch'.
    #
    # repo   - Grit::Repo instance.
    # sha    - String SHA of the Commit.
    # size   - Fixnum size of the object.
    # object - Parsed String output from `git cat-file --batch`.
    #
    # Returns an Array of Grit::Commit objects.
    def self.parse_batch(repo, sha, size, object)
      info, message = object.split("\n\n", 2)

      lines = info.split("\n")
      tree = lines.shift.split(' ', 2).last
      parents = []
      parents << lines.shift[7..-1] while lines.first[0, 6] == 'parent'
      author,    authored_date  = Grit::Commit.actor(lines.shift)
      committer, committed_date = Grit::Commit.actor(lines.shift)

      Grit::Commit.new(
        repo, sha, parents, tree,
        author, authored_date,
        committer, committed_date,
        message.to_s.split("\n"))
    end

    # Instantiate a new Commit
    #   +id+ is the id of the commit
    #   +parents+ is an array of commit ids (will be converted into Commit instances)
    #   +tree+ is the correspdonding tree id (will be converted into a Tree object)
    #   +author+ is the author string
    #   +authored_date+ is the authored Time
    #   +committer+ is the committer string
    #   +committed_date+ is the committed Time
    #   +message+ is an array of commit message lines
    #
    # Returns Grit::Commit (baked)
    def initialize(repo, id, parents, tree, author, authored_date, committer, committed_date, message)
      @repo = repo
      @id = id
      @parents = parents.map { |p| Commit.create(repo, :id => p) }
      @tree = Tree.create(repo, :id => tree)
      @author = author
      @authored_date = authored_date
      @committer = committer
      @committed_date = committed_date
      @message = message.join("\n")
      @short_message = message.find { |x| !x.strip.empty? } || ''
    end

    def id_abbrev
      @id_abbrev ||= @repo.git.rev_parse({}, self.id).chomp[0, 7]
    end

    # Create an unbaked Commit containing just the specified attributes
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Commit (unbaked)
    def self.create(repo, atts)
      self.allocate.create_initialize(repo, atts)
    end

    # Initializer for Commit.create
    #   +repo+ is the Repo
    #   +atts+ is a Hash of instance variable data
    #
    # Returns Grit::Commit (unbaked)
    def create_initialize(repo, atts)
      @repo = repo
      atts.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
      self
    end

    def lazy_source
      self.class.find_all(@repo, @id, {:max_count => 1}).first
    end

    # Count the number of commits reachable from this ref
    #   +repo+ is the Repo
    #   +ref+ is the ref from which to begin (SHA1 or name)
    #
    # Returns Integer
    def self.count(repo, ref)
      repo.git.rev_list({}, ref).size / 41
    end

    # Find all commits matching the given criteria.
    #   +repo+ is the Repo
    #   +ref+ is the ref from which to begin (SHA1 or name) or nil for --all
    #   +options+ is a Hash of optional arguments to git
    #     :max_count is the maximum number of commits to fetch
    #     :skip is the number of commits to skip
    #
    # Returns Grit::Commit[] (baked)
    def self.find_all(repo, ref, options = {})
      allowed_options = [:max_count, :skip, :since]

      default_options = {:pretty => "raw"}
      actual_options = default_options.merge(options)

      if ref
        output = repo.git.rev_list(actual_options, ref)
      else
        output = repo.git.rev_list(actual_options.merge(:all => true))
      end

      self.list_from_string(repo, output)
    rescue Grit::GitRuby::Repository::NoSuchShaFound
      []
    end

    # Parse out commit information into an array of baked Commit objects
    #   +repo+ is the Repo
    #   +text+ is the text output from the git command (raw format)
    #
    # Returns Grit::Commit[] (baked)
    #
    # really should re-write this to be more accepting of non-standard commit messages
    # - it broke when 'encoding' was introduced - not sure what else might show up
    #
    def self.list_from_string(repo, text)
      lines = text.split("\n")

      commits = []

      while !lines.empty?
        id = lines.shift.split.last
        tree = lines.shift.split.last

        parents = []
        parents << lines.shift.split.last while lines.first =~ /^parent/

        author_line = lines.shift
        author_line << lines.shift if lines[0] !~ /^committer /
        author, authored_date = self.actor(author_line)

        committer_line = lines.shift
        committer_line << lines.shift if lines[0] && lines[0] != '' && lines[0] !~ /^encoding/
        committer, committed_date = self.actor(committer_line)

        # not doing anything with this yet, but it's sometimes there
        encoding = lines.shift.split.last if lines.first =~ /^encoding/

        lines.shift

        message_lines = []
        message_lines << lines.shift[4..-1] while lines.first =~ /^ {4}/

        lines.shift while lines.first && lines.first.empty?

        commits << Commit.new(repo, id, parents, tree, author, authored_date, committer, committed_date, message_lines)
      end

      commits
    end

    # Show diffs between two trees.
    #
    # repo    - The current Grit::Repo instance.
    # a       - A String named commit.
    # b       - An optional String named commit.  Passing an array assumes you
    #           wish to omit the second named commit and limit the diff to the
    #           given paths.
    # paths   - An optional Array of paths to limit the diff.
    # options - An optional Hash of options.  Merged into {:full_index => true}.
    #
    # Returns Grit::Diff[] (baked)
    def self.diff(repo, a, b = nil, paths = [], options = {})
      if b.is_a?(Array)
        paths = b
        b     = nil
      end
      paths.unshift("--") unless paths.empty?
      paths.unshift(b)    unless b.nil?
      paths.unshift(a)
      options = {:full_index => true}.update(options)
      text    = repo.git.diff(options, *paths)
      Diff.list_from_string(repo, text)
    end

    def show
      if parents.size > 1
        diff = @repo.git.native(:diff, {:full_index => true}, "#{parents[0].id}...#{parents[1].id}")
      else
        diff = @repo.git.show({:full_index => true, :pretty => 'raw'}, @id)
      end

      if diff =~ /diff --git a/
        diff = diff.sub(/.+?(diff --git a)/m, '\1')
      else
        diff = ''
      end
      Diff.list_from_string(@repo, diff)
    end

    # Shows diffs between the commit's parent and the commit.
    #
    # options - An optional Hash of options, passed to Grit::Commit.diff.
    #
    # Returns Grit::Diff[] (baked)
    def diffs(options = {})
      if parents.empty?
        show
      else
        self.class.diff(@repo, parents.first.id, @id, [], options)
      end
    end

    def stats
      stats = @repo.commit_stats(self.sha, 1)[0][-1]
    end

    # Convert this Commit to a String which is just the SHA1 id
    def to_s
      @id
    end

    def sha
      @id
    end

    def date
      @committed_date
    end

    def to_patch
      @repo.git.format_patch({'1' => true, :stdout => true}, to_s)
    end

    def notes
      ret = {}
      notes = Note.find_all(@repo)
      notes.each do |note|
        if n = note.commit.tree/(self.id)
          ret[note.name] = n.data
        end
      end
      ret
    end

    # Calculates the commit's Patch ID. The Patch ID is essentially the SHA1
    # of the diff that the commit is introducing.
    #
    # Returns the 40 character hex String if a patch-id could be calculated
    #   or nil otherwise.
    def patch_id
      show = @repo.git.show({}, @id)
      patch_line = @repo.git.native(:patch_id, :input => show)
      if patch_line =~ /^([0-9a-f]{40}) [0-9a-f]{40}\n$/
        $1
      else
        nil
      end
    end

    # Pretty object inspection
    def inspect
      %Q{#<Grit::Commit "#{@id}">}
    end

    # private

    # Parse out the actor (author or committer) info
    #
    # Returns [String (actor name and email), Time (acted at time)]
    def self.actor(line)
      m, actor, epoch = *line.match(/^.+? (.*) (\d+) .*$/)
      [Actor.from_string(actor), Time.at(epoch.to_i)]
    end

    def author_string
      "%s <%s> %s %+05d" % [author.name, author.email, authored_date.to_i, 800]
    end

    def to_hash
      {
        'id'       => id,
        'parents'  => parents.map { |p| { 'id' => p.id } },
        'tree'     => tree.id,
        'message'  => message,
        'author'   => {
          'name'  => author.name,
          'email' => author.email
        },
        'committer' => {
          'name'  => committer.name,
          'email' => committer.email
        },
        'authored_date'  => authored_date.xmlschema,
        'committed_date' => committed_date.xmlschema,
      }
    end
  end # Commit

end # Grit
