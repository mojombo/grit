module Grit

  class Index
    # Public: Gets/Sets the Grit::Repo to which this index belongs.
    attr_accessor :repo

    # Public: Gets/Sets the Hash tree map that holds the changes to be made
    # in the next commit.
    attr_accessor :tree

    # Public: Gets/Sets the Grit::Tree object representing the tree upon
    # which the next commit will be based.
    attr_accessor :current_tree

    # Public: if a tree or commit is written, this stores the size of that object
    attr_reader :last_tree_size
    attr_reader :last_commit_size

    # Initialize a new Index object.
    #
    # repo - The Grit::Repo to which the index belongs.
    #
    # Returns the newly initialized Grit::Index.
    def initialize(repo)
      self.repo = repo
      self.tree = {}
      self.current_tree = nil
    end

    # Public: Add a file to the index.
    #
    # path - The String file path including filename (no slash prefix).
    # data - The String binary contents of the file.
    #
    # Returns nothing.
    def add(path, data)
      path = path.split('/')
      filename = path.pop

      current = self.tree

      path.each do |dir|
        current[dir] ||= {}
        node = current[dir]
        current = node
      end

      current[filename] = data
    end

    # Public: Delete the given file from the index.
    #
    # path - The String file path including filename (no slash prefix).
    #
    # Returns nothing.
    def delete(path)
      add(path, false)
    end

    # Public: Read the contents of the given Tree into the index to use as a
    # starting point for the index.
    #
    # tree - The String branch/tag/sha of the Git tree object.
    #
    # Returns nothing.
    def read_tree(tree)
      self.current_tree = self.repo.tree(tree)
    end

    # Public: Commit the contents of the index.  This method supports two
    # formats for arguments:
    #
    # message - The String commit message.
    # options - An optional Hash of index options.
    #           :parents        - Array of String commit SHA1s or Grit::Commit
    #                             objects to attach this commit to to form a 
    #                             new head (default: nil).
    #           :actor          - The Grit::Actor details of the user making
    #                             the commit (default: nil).
    #           :last_tree      - The String SHA1 of a tree to compare with
    #                             in order to avoid making empty commits
    #                             (default: nil).
    #           :head           - The String branch name to write this head to
    #                             (default: nil).
    #           :committed_date - The Time that the commit was made.
    #                             (Default: Time.now)
    #           :authored_date  - The Time that the commit was authored.
    #                             (Default: committed_date)
    #
    # The legacy argument style looks like:
    #
    # message   - The String commit message.
    # parents   - Array of String commit SHA1s or Grit::Commit objects to
    #             attach this commit to to form a new head (default: nil).
    # actor     - The Grit::Actor details of the user making the commit
    #             (default: nil).
    # last_tree - The String SHA1 of a tree to compare with in order to avoid
    #             making empty commits (default: nil).
    # head      - The String branch name to write this head to
    #             (default: "master").
    #
    # Returns a String of the SHA1 of the new commit.
    def commit(message, parents = nil, actor = nil, last_tree = nil, head = 'master')
      commit_tree_sha = nil
      if parents.is_a?(Hash)
        commit_tree_sha = parents[:commit_tree_sha]
        actor          = parents[:actor]
        committer      = parents[:committer]
        author         = parents[:author]
        last_tree      = parents[:last_tree]
        head           = parents[:head]
        committed_date = parents[:committed_date]
        authored_date  = parents[:authored_date]
        parents        = parents[:parents]
      end

      committer ||= actor
      author    ||= committer

      if commit_tree_sha
        tree_sha1 = commit_tree_sha
      else
        tree_sha1 = write_tree(self.tree, self.current_tree)
      end

      # don't write identical commits
      return false if tree_sha1 == last_tree

      contents = []
      contents << ['tree', tree_sha1].join(' ')
      parents.each do |p|
        contents << ['parent', p].join(' ')
      end if parents

      committer      ||= begin
        config = Config.new(self.repo)
        Actor.new(config['user.name'], config['user.email'])
      end
      author         ||= committer
      committed_date ||= Time.now
      authored_date  ||= committed_date

      contents << ['author',    author.output(authored_date)].join(' ')
      contents << ['committer', committer.output(committed_date)].join(' ')
      contents << ''
      contents << message

      contents = contents.join("\n")
      @last_commit_size = contents.size
      commit_sha1 = self.repo.git.put_raw_object(contents, 'commit')

      self.repo.update_ref(head, commit_sha1) if head
      commit_sha1
    end

    # Recursively write a tree to the index.
    #
    # tree -     The Hash tree map:
    #            key - The String directory or filename.
    #            val - The Hash submap or the String contents of the file.
    # now_tree - The Grit::Tree representing the a previous tree upon which
    #            this tree will be based (default: nil).
    #
    # Returns the String SHA1 String of the tree.
    def write_tree(tree = nil, now_tree = nil)
      tree = self.tree if !tree
      tree_contents = {}

      # fill in original tree
      now_tree = read_tree(now_tree) if(now_tree && now_tree.is_a?(String))
      now_tree.contents.each do |obj|
        sha = [obj.id].pack("H*")
        k = obj.name
        k += '/' if (obj.class == Grit::Tree)
        tmode = obj.mode.to_i.to_s  ## remove zero-padding
        tree_contents[k] = "%s %s\0%s" % [tmode, obj.name, sha]
      end if now_tree

      # overwrite with new tree contents
      tree.each do |k, v|
        case v
          when Array
            sha, mode = v
            if sha.size == 40        # must be a sha
              sha = [sha].pack("H*")
              mode = mode.to_i.to_s  # leading 0s not allowed
              k = k.split('/').last  # slashes not allowed
              str = "%s %s\0%s" % [mode, k, sha]
              tree_contents[k] = str
            end
          when String
            sha = write_blob(v)
            sha = [sha].pack("H*")
            str = "%s %s\0%s" % ['100644', k, sha]
            tree_contents[k] = str
          when Hash
            ctree = now_tree/k if now_tree
            sha = write_tree(v, ctree)
            sha = [sha].pack("H*")
            str = "%s %s\0%s" % ['40000', k, sha]
            tree_contents[k + '/'] = str
          when false
            tree_contents.delete(k)
        end
      end

      tr = tree_contents.sort.map { |k, v| v }.join('')
      @last_tree_size = tr.size
      self.repo.git.put_raw_object(tr, 'tree')
    end

    # Write a blob to the index.
    #
    # data - The String data to write.
    #
    # Returns the String SHA1 of the new blob.
    def write_blob(data)
      self.repo.git.put_raw_object(data, 'blob')
    end
  end # Index

end # Grit
