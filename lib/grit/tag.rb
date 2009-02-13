module Grit

  class Tag < Ref
    def self.find_all(repo, options = {})
      refs = []
      already = {}

      Dir.chdir(repo.path) do
        files = Dir.glob(prefix + '/**/*')

        files.each do |ref|
          next if !File.file?(ref)

          id = File.read(ref).chomp
          name = ref.sub("#{prefix}/", '')
          commit = commit_from_sha(repo, id)

          if !already[name]
            refs << self.new(name, commit)
            already[name] = true
          end
        end

        if File.file?('packed-refs')
          lines = File.readlines('packed-refs')
          lines.each_with_index do |line, i|
            if m = /^(\w{40}) (.*?)$/.match(line)
              next if !Regexp.new('^' + prefix).match(m[2])
              name = m[2].sub("#{prefix}/", '')

              # Annotated tags in packed-refs include a reference
              # to the commit object on the following line.
              next_line = lines[i+1]
              if next_line && next_line[0] == ?^
                commit = Commit.create(repo, :id => next_line[1..-1].chomp)
              else
                commit = commit_from_sha(repo, m[1])
              end

              if !already[name]
                refs << self.new(name, commit)
                already[name] = true
              end
            end
          end
        end
      end

      refs
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
