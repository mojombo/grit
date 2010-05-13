module Grit

  class Tag < Ref
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

    def lazy_source
      data         = commit.repo.git.cat_ref({:p => true}, name)
      @message     = commit.short_message
      @tagger      = commit.author
      @tag_date    = commit.authored_date
      return self if data.empty?

      if data =~ /^object/
        @message = ''
        lines = data.split("\n")
        lines.shift # type commit
        lines.shift # tag name
        lines.shift
        @tagger, @tag_date = Commit.actor(lines.shift)
        lines.shift # blank line
        while lines.first && lines.first !~ /-----BEGIN PGP SIGNATURE-----/
          @message << lines.shift << "\n"
        end
        @message.strip!
      end
      self
    end
  end

end
