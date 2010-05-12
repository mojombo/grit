module Grit

  class Tag < Ref
    lazy_reader :message

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
      repo  = @commit.repo
      lines = repo.git.cat_ref({:p => true}, name).split("\n")
      @message = ''
      if lines.shift =~ /^object/
        lines.shift # type commit
        lines.shift # tag name
        lines.shift # tagger
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
