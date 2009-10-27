module Grit

  class CommitStats

    attr_reader :id, :files, :additions, :deletions, :total

    # Instantiate a new CommitStats
    #   +id+ is the id of the commit
    #   +files+ is an array of :
    #     [ [filename, adds, deletes, total],
    #       [filename, adds, deletes, total],
    #       [filename, adds, deletes, total] ]
    #
    # Returns Grit::CommitStats (baked)
    def initialize(repo, id, files)
      @repo = repo
      @id = id
      @files = files
      @additions  = files.inject(0) { |total, a| total += a[1] }
      @deletions  = files.inject(0) { |total, a| total += a[2] }
      @total  = files.inject(0) { |total, a| total += a[3] }
    end

    # Find all commit stats matching the given criteria.
    #   +repo+ is the Repo
    #   +ref+ is the ref from which to begin (SHA1 or name) or nil for --all
    #   +options+ is a Hash of optional arguments to git
    #     :max_count is the maximum number of commits to fetch
    #     :skip is the number of commits to skip
    #
    # Returns assoc array [sha, Grit::Commit[] (baked)]
    def self.find_all(repo, ref, options = {})
      allowed_options = [:max_count, :skip, :since]

      default_options = {:numstat => true}
      actual_options = default_options.merge(options)

      if ref
        output = repo.git.log(actual_options, ref)
      else
        output = repo.git.log(actual_options.merge(:all => true))
      end

      self.list_from_string(repo, output)
    end

    # Parse out commit information into an array of baked Commit objects
    #   +repo+ is the Repo
    #   +text+ is the text output from the git command (raw format)
    #
    # Returns assoc array [sha, Grit::Commit[] (baked)]
    def self.list_from_string(repo, text)
      lines = text.split("\n")

      commits = []

      while !lines.empty?
        id = lines.shift.split.last

        lines.shift
        lines.shift
        lines.shift

        message_lines = []
        message_lines << lines.shift[4..-1] while lines.first =~ /^ {4}/ || lines.first == ''

        lines.shift while lines.first && lines.first.empty?

        files = []
        while lines.first =~ /^([-\d]+)\s+([-\d]+)\s+(.+)/
          (additions, deletions, filename) = lines.shift.split
          additions = additions.to_i
          deletions = deletions.to_i
          total = additions + deletions
          files << [filename, additions, deletions, total]
        end

        lines.shift while lines.first && lines.first.empty?

        commits << [id, CommitStats.new(repo, id, files)]
      end

      commits
    end

    # Pretty object inspection
    def inspect
      %Q{#<Grit::CommitStats "#{@id}">}
    end

    # Convert to an easy-to-traverse structure
    def to_diffstat
      files.map do |metadata|
        DiffStat.new(*metadata)
      end
    end

    # private

    def to_hash
      {
        'id'        => id,
        'files'     => files,
        'additions' => additions,
        'deletions' => deletions,
        'total'     => total
      }
    end

  end # CommitStats

  class DiffStat
    attr_reader :filename, :additions, :deletions

    def initialize(filename, additions, deletions, total=nil)
      @filename, @additions, @deletions = filename, additions, deletions
    end

    def net
      additions - deletions
    end

    def inspect
      "#{filename}: +#{additions} -#{deletions}"
    end
  end

end # Grit
