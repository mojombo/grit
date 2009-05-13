module Grit

  class Tag < Ref
    def self.find_all(repo, options = {})
      refs = repo.git.refs(options, prefix)
      refs.split("\n").map do |ref|
        name, id = *ref.split(' ')
        commit = commit_from_sha(repo, id)
        self.new(name, commit)
      end
    end

    def self.commit_from_sha(repo, id)
      git_ruby_repo = GitRuby::Repository.new(repo.path)
      object = git_ruby_repo.get_object_by_sha1(id)

      if object.type == :commit
        Commit.create(repo, :id => id)
      elsif object.type == :tag
        Commit.create(repo, :id => object.object)
      else
        raise "Unknown object type."
      end
    end
  end

end
