module Grit

  class Tag < Ref
    def self.find_all(repo, options = {})
      refs = []
      already = {}
      git_ruby_repo = GitRuby::Repository.new(repo.path)

      Dir.chdir(repo.path) do
        files = Dir.glob(prefix + '/**/*')

        files.each do |ref|
          next if !File.file?(ref)

          id = File.read(ref).chomp
          name = ref.sub("#{prefix}/", '')
          object = git_ruby_repo.get_object_by_sha1(id)

          if object.type == :commit
            commit = Commit.create(repo, :id => id)
          elsif object.type == :tag
            commit = Commit.create(repo, :id => object.object)
          else
            raise "Unknown object type."
          end

          if !already[name]
            refs << self.new(name, commit)
            already[name] = true
          end
        end

        if File.file?('packed-refs')
          File.readlines('packed-refs').each do |line|
            if m = /^(\w{40}) (.*?)$/.match(line)
              next if !Regexp.new('^' + prefix).match(m[2])
              name = m[2].sub("#{prefix}/", '')
              commit = Commit.create(repo, :id => m[1])
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
  end

end
