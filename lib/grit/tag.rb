module Grit

  class Tag < Ref
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
  end

end
