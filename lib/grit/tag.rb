module Grit

  class Tag < Ref
    lazy_reader :message
    lazy_reader :tagger
    lazy_reader :tag_date

    def self.find_all(repo, options = {})
      refs = repo.git.refs(options, prefix)
      refs.split("\n").map do |ref|
        name, id = *ref.split(' ')
        cid = repo.git.commit_from_sha(id)
        raise "Unknown object type." if cid == ''
        commit = Commit.create(repo, :id => cid)
        self.new(name, commit)
      end
    end

    def lazy_source
      repo = @commit.repo
      data = repo.git.cat_ref({:p => true}, name)
      @message = ''
      return self if data.empty?

      if data =~ /^object/
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
      else # lightweight tag, grab just the commit message
        @tagger   = commit.author
        @tag_date = commit.authored_date
        @message  = commit.short_message
      end
      self
    end
  end

end
