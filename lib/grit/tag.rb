module Grit

  class Tag < Ref
    extend Lazy

    lazy_reader :message
    lazy_reader :tagger
    lazy_reader :tag_date

    def self.find_all(repo, options = {})
      refs = repo.git.refs(options, prefix)
      refs.split("\n").map do |ref|
        name, id = *ref.split(' ')
        sha = repo.git.commit_from_sha(id)
        raise "Unknown object type." if sha == ''
        commit = Commit.create(repo, :id => sha)
        new(name, commit)
      end
    end

    # Parses the results from `cat-file -p`
    #
    # data - String tag object data.  Example:
    #          object 7bcc0ee821cdd133d8a53e8e7173a334fef448aa
    #          type commit
    #          tag v0.7.0
    #          tagger USER <EMAIL> DATE
    #          
    #          v0.7.0
    #
    # Returns parsed Hash.  Example: 
    #   {:message => "...", :tagger => "bob", :tag_date => ...}
    def self.parse_tag_data(data)
      return unless data =~ /^object/
      parsed = {}
      lines  = data.split("\n")
      lines.shift # type commit
      lines.shift # tag name
      lines.shift
      author_line = lines.shift
      parsed[:tagger], parsed[:tag_date] = Commit.actor(author_line)
      if !parsed[:tagger] || !parsed[:tagger].name
        parsed[:tag_date] ||= Time.utc(1970)
        parsed[:tagger]     = Actor.from_string(author_line.sub(/^tagger /, ''))
      end
      lines.shift # blank line
      parsed[:message] = []
      while lines.first && lines.first !~ /-----BEGIN PGP SIGNATURE-----/
        parsed[:message] << lines.shift
      end
      parsed[:message] = parsed[:message] * "\n"
      parsed
    end

    def lazy_source
      data         = commit.repo.git.cat_ref({:p => true}, name)
      @message     = commit.short_message
      @tagger      = commit.author
      @tag_date    = commit.authored_date
      return self if data.empty?

      if parsed = self.class.parse_tag_data(data)
        @message  = parsed[:message]
        @tagger   = parsed[:tagger]
        @tag_date = parsed[:tag_date]
      end
      self
    end
  end

end
