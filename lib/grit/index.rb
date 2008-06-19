module Grit
  
  class Index
    attr_accessor :repo, :tree
    
    def initialize(repo)
      self.repo = repo
      self.tree = {}
    end
    
    # Add a file to the index
    #   +path+ is the path (including filename)
    #   +data+ is the binary contents of the file
    #
    # Returns nothing
    def add(file_path, data)
      path = file_path.split('/')
      filename = path.pop
      
      current = self.tree
      
      path.each do |dir|
        current[dir] ||= {}
        node = current[dir]
        current = node
      end
      
      current[filename] = data
    end
        
    # Commit the contents of the index
    #   +message+ is the commit message
    #
    # Returns a String of the SHA1 of the commit
    def commit(message, parents = nil, actor = nil, last_tree = nil)
      tree_sha1 = write_tree(self.tree)
      return false if tree_sha1 == last_tree # don't write identical commits
      
      contents = []
      contents << ['tree', tree_sha1].join(' ')
      parents.each do |p|
        contents << ['parent', p].join(' ') if p        
      end if parents

      if actor
        name = actor.name
        email = actor.email
      else
        config = Config.new(self.repo)
        name = config['user.name']
        email = config['user.email']
      end
    
      author_string = "#{name} <#{email}> #{Time.now.to_i} -0700" # !! TODO : gotta fix this
      contents << ['author', author_string].join(' ')
      contents << ['committer', author_string].join(' ')
      contents << ''
      contents << message
      
      commit_sha1 = self.repo.git.ruby_git.put_raw_object(contents.join("\n"), 'commit')      
      
      # self.repo.git.update_ref({}, 'HEAD', commit_sha1)
      File.open(File.join(self.repo.path, 'refs', 'heads', 'master'), 'w') do |f|
        f.write(commit_sha1)
      end if commit_sha1
      
      commit_sha1
    end
    
    # Recursively write a tree to the index
    #   +tree+ is the tree
    #
    # Returns the SHA1 String of the tree
    def write_tree(tree)
      tree_contents = ''
      tree.each do |k, v|
        case v
          when String:
            sha = write_blob(v)
            sha = [sha].pack("H*")
            str = "%s %s\0%s" % ['100644', k, sha]
            tree_contents += str
          when Hash:
            sha = write_tree(v)
            sha = [sha].pack("H*")
            str = "%s %s\0%s" % ['040000', k, sha]
            tree_contents += str
        end
      end
      self.repo.git.ruby_git.put_raw_object(tree_contents, 'tree')
    end
    
    # Write the blob to the index
    #   +data+ is the data to write
    #
    # Returns the SHA1 String of the blob
    def write_blob(data)
      self.repo.git.ruby_git.put_raw_object(data, 'blob')
    end
  end # Index
  
end # Grit
