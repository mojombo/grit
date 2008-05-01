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
    def commit(message)
      tree_sha1 = write_tree(self.tree)
      
      message = message.gsub("'", "\\'")
      commit_sha1 = self.repo.git.run("echo '#{message}' | ", :commit_tree, '', {}, [tree_sha1])
      
      # self.repo.git.update_ref({}, 'HEAD', commit_sha1)
      File.open(File.join(self.repo.path, 'refs', 'heads', 'master'), 'w') do |f|
        f.write(commit_sha1)
      end
      
      commit_sha1
    end
    
    # Recursively write a tree to the index
    #   +tree+ is the tree
    #
    # Returns the SHA1 String of the tree
    def write_tree(tree)
      lstree = []
      tree.each do |k, v|
        case v
          when String:
            lstree << "100644 blob #{write_blob(v)}\t#{k}"
          when Hash:
            lstree << "040000 tree #{write_tree(v)}\t#{k}"
        end
      end
      
      lstree_string = lstree.join("\n").gsub("'", "\\'")
      self.repo.git.run("echo '#{lstree_string}' | ", :mktree, '', {}, []).chomp
    end
    
    # Write the blob to the index
    #   +data+ is the data to write
    #
    # Returns the SHA1 String of the blob
    def write_blob(data)
      self.repo.git.run("echo '#{data}' | ", :hash_object, '', {:w => true, :stdin => true}, []).chomp
    end
  end # Index
  
end # Grit
