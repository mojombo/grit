module Grit

  class Index
    attr_accessor :repo, :tree, :current_tree

    def initialize(repo)
      self.repo = repo
      self.tree = {}
      self.current_tree = nil
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

    # Sets the current tree
    #   +tree+ the branch/tag/sha... to use - a string
    #
    # Returns index (self)
    def read_tree(tree)
      self.current_tree = self.repo.tree(tree)
    end

    # Commit the contents of the index
    #   +message+ is the commit message [nil]
    #   +parents+ is one or more commits to attach this commit to to form a new head [nil]
    #   +actor+ is the details of the user making the commit [nil]
    #   +last_tree+ is a tree to compare with - to avoid making empty commits [nil]
    #   +head+ is the branch to write this head to [master]
    #
    # Returns a String of the SHA1 of the commit
    def commit(message, parents = nil, actor = nil, last_tree = nil, head = 'master')
      tree_sha1 = write_tree(self.tree, self.current_tree)
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

      commit_sha1 = self.repo.git.put_raw_object(contents.join("\n"), 'commit')

      self.repo.update_ref(head, commit_sha1)
    end

    # Recursively write a tree to the index
    #   +tree+ is the tree
    #
    # Returns the SHA1 String of the tree
    def write_tree(tree, now_tree = nil)
      tree_contents = {}

      # fill in original tree
      now_tree.contents.each do |obj|
        sha = [obj.id].pack("H*")
        k = obj.name
        k += '/' if (obj.class == Grit::Tree)
        tree_contents[k] = "%s %s\0%s" % [obj.mode.to_s, obj.name, sha]
      end if now_tree

      # overwrite with new tree contents
      tree.each do |k, v|
        case v
          when String
            sha = write_blob(v)
            sha = [sha].pack("H*")
            str = "%s %s\0%s" % ['100644', k, sha]
            tree_contents[k] = str
          when Hash
            ctree = now_tree/k if now_tree
            sha = write_tree(v, ctree)
            sha = [sha].pack("H*")
            str = "%s %s\0%s" % ['040000', k, sha]
            tree_contents[k + '/'] = str
        end
      end
      tr = tree_contents.sort.map { |k, v| v }.join('')
      self.repo.git.put_raw_object(tr, 'tree')
    end

    # Write the blob to the index
    #   +data+ is the data to write
    #
    # Returns the SHA1 String of the blob
    def write_blob(data)
      self.repo.git.put_raw_object(data, 'blob')
    end
  end # Index

end # Grit
