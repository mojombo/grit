#
# converted from the gitrb project
#
# authors:
#    Matthias Lederhofer <matled@gmx.net>
#    Simon 'corecode' Schubert <corecode@fs.ei.tum.de>
#    Scott Chacon <schacon@gmail.com>
#
# provides native ruby access to git objects and pack files
#
require 'grit/git-ruby/internal/raw_object'
require 'grit/git-ruby/internal/pack'
require 'grit/git-ruby/internal/loose'
require 'grit/git-ruby/git_object'

require 'rubygems'
require 'diff/lcs'
require 'diff/lcs/hunk'

# have to do this so it doesn't interfere with Grit::Diff
module Difference
  include Diff
end

module Grit
  module GitRuby
    class Repository

      class NoSuchShaFound < StandardError
      end

      class NoSuchPath < StandardError
      end

      attr_accessor :git_dir, :options

      def initialize(git_dir, options = {})
        @git_dir = git_dir
        @options = options
        @packs = []
      end

      # returns the loose objects object lazily
      def loose
        @loose ||= initloose
      end

      # returns the array of pack list objects
      def packs
        @packs ||= initpacks
      end


      # prints out the type, shas and content of all of the pack files
      def show
        packs.each do |p|
          puts p.name
          puts
          p.each_sha1 do |s|
            puts "**#{p[s].type}**"
            if p[s].type.to_s == 'commit'
              puts s.unpack('H*')
              puts p[s].content
            end
          end
          puts
        end
      end


      # returns a raw object given a SHA1
      def get_raw_object_by_sha1(sha1o)
        raise NoSuchShaFound if sha1o.nil? || sha1o.empty? || !sha1o.is_a?(String)

        sha1 = [sha1o.chomp].pack("H*")
        # try packs
        packs.each do |pack|
          o = pack[sha1]
          return pack[sha1] if o
        end

        # try loose storage
        loose.each do |lsobj|
          o = lsobj[sha1]
          return o if o
        end

        # try packs again, maybe the object got packed in the meantime
        initpacks
        packs.each do |pack|
          o = pack[sha1]
          return o if o
        end

#        puts "*#{sha1o}*"
        raise NoSuchShaFound
      end

      def cached(key, object, do_cache = true)
        object
      end

      # returns GitRuby object of any type given a SHA1
      def get_object_by_sha1(sha1)
        r = get_raw_object_by_sha1(sha1)
        return nil if !r
        GitObject.from_raw(r)
      end

      # writes a raw object into the git repo
      def put_raw_object(content, type)
        loose.first.put_raw_object(content, type)
      end

      # returns true or false if that sha exists in the db
      def object_exists?(sha1)
        sha_hex = [sha1].pack("H*")
        return true if in_packs?(sha_hex)
        return true if in_loose?(sha_hex)
        initpacks
        return true if in_packs?(sha_hex) #maybe the object got packed in the meantime
        false
      end

      # returns true if the hex-packed sha is in the packfiles
      def in_packs?(sha_hex)
        # try packs
        packs.each do |pack|
          return true if pack[sha_hex]
        end
        false
      end

      # returns true if the hex-packed sha is in the loose objects
      def in_loose?(sha_hex)
        loose.each do |lsobj|
          return true if lsobj[sha_hex]
        end
        false
      end


      # returns the file type (as a symbol) of this sha
      def cat_file_type(sha)
        get_raw_object_by_sha1(sha).type
      end

      # returns the file size (as an int) of this sha
      def cat_file_size(sha)
        get_raw_object_by_sha1(sha).content.size
      end

      # returns the raw file contents of this sha
      def cat_file(sha)
        get_object_by_sha1(sha).raw_content
      end

      # returns a 2-d hash of the tree
      # ['blob']['FILENAME'] = {:mode => '100644', :sha => SHA}
      # ['tree']['DIRNAME'] = {:mode => '040000', :sha => SHA}
      def list_tree(sha)
        data = {'blob' => {}, 'tree' => {}, 'link' => {}, 'commit' => {}}
        get_object_by_sha1(sha).entry.each do |e|
          data[e.format_type][e.name] = {:mode => e.format_mode, :sha => e.sha1}
        end
        data
      end

      # returns the raw (cat-file) output for a tree
      # if given a commit sha, it will print the tree of that commit
      # if given a path limiter array, it will limit the output to those
      # if asked for recrusive trees, will traverse trees
      def ls_tree(sha, paths = [], recursive = false)
        if paths.size > 0
          # pathing
          part = []
          paths.each do |path|
            part += ls_tree_path(sha, path)
          end
          return part.join("\n")
        else
          get_raw_tree(sha, recursive)
        end
      end

      def get_raw_tree(sha, recursive = false)
        o = get_raw_object_by_sha1(sha)
        if o.type == :commit
          tree = get_object_by_sha1(sha).tree
        elsif o.type == :tag
          commit_sha = get_object_by_sha1(sha).object
          tree = get_object_by_sha1(commit_sha).tree
        elsif o.type == :tree
          tree = sha
        else
          return nil
        end

        recursive ? get_raw_trees(tree) : cat_file(tree)
      end

      # Grabs tree contents recursively,
      #   e.g. `git ls-tree -r sha`
      def get_raw_trees(sha, path = '')
        out = ''
        cat_file(sha).split("\n").each do |line|
          mode, type, sha, name = line.split(/\s/)

          if type == 'tree'
            full_name = path.empty? ? name : "#{path}/#{name}"
            out << get_raw_trees(sha, full_name)
          elsif path.empty?
            out << line + "\n"
          else
            out << line.gsub(name, "#{path}/#{name}") + "\n"
          end
        end

        out
      end

      # return array of tree entries
      ## TODO : refactor this to remove the fugly
      def ls_tree_path(sha, path, append = nil)
        tree = get_raw_tree(sha)
        if path =~ /\//
          paths = path.split('/')
          last = path[path.size - 1, 1]
          if (last == '/') && (paths.size == 1)
            append = append ? File.join(append, paths.first) : paths.first
            dir_name = tree.split("\n").select { |p| p.split("\t")[1] == paths.first }.first
            raise NoSuchPath if !dir_name
            next_sha = dir_name.split(' ')[2]
            tree = get_raw_tree(next_sha)
            tree = tree.split("\n")
            if append
              mod_tree = []
              tree.each do |ent|
                (info, fpath) = ent.split("\t")
                mod_tree << [info, File.join(append, fpath)].join("\t")
              end
              mod_tree
            else
              tree
            end
          else
            raise NoSuchPath if tree.nil?
            next_path = paths.shift
            dir_name = tree.split("\n").select { |p| p.split("\t")[1] == next_path }.first
            raise NoSuchPath if !dir_name
            next_sha = dir_name.split(' ')[2]
            next_path = append ? File.join(append, next_path) : next_path
            if (last == '/')
              ls_tree_path(next_sha, paths.join("/") + '/', next_path)
            else
              ls_tree_path(next_sha, paths.join("/"), next_path)
            end
          end
        else
          raise NoSuchPath if tree.nil?
          tree = tree.split("\n")
          tree = tree.select { |p| p.split("\t")[1] == path }
          if append
            mod_tree = []
            tree.each do |ent|
              (info, fpath) = ent.split("\t")
              mod_tree << [info, File.join(append, fpath)].join("\t")
            end
            mod_tree
          else
            tree
          end
        end
      end

      # returns an array of GitRuby Commit objects
      # [ [sha, raw_output], [sha, raw_output], [sha, raw_output] ... ]
      #
      # takes the following options:
      #  :since - Time object specifying that you don't want commits BEFORE this
      #  :until - Time object specifying that you don't want commit AFTER this
      #  :first_parent - tells log to only walk first parent
      #  :path_limiter - string or array of strings to limit path
      #  :max_count - number to limit the output
      def log(sha, options = {})
        @already_searched = {}
        walk_log(sha, options)
      end

      def truncate_arr(arr, sha)
        new_arr = []
        arr.each do |a|
          if a[0] == sha
            return new_arr
          end
          new_arr << a
        end
        return new_arr
      end

      def rev_list(sha, options)
        if sha.is_a? Array
          (end_sha, sha) = sha
        end

        log = log(sha, options)
        log = log.sort { |a, b| a[2] <=> b[2] }.reverse

        if end_sha
          log = truncate_arr(log, end_sha)
        end

        # shorten the list if it's longer than max_count (had to get everything in branches)
        if options[:max_count]
          if (opt_len = options[:max_count].to_i) < log.size
            log = log[0, opt_len]
          end
        end

        if options[:pretty] == 'raw'
          log.map {|k, v| v }.join('')
        else
          log.map {|k, v| k }.join("\n")
        end
      end

      # called by log() to recursively walk the tree
      def walk_log(sha, opts, total_size = 0)
        return [] if @already_searched[sha] # to prevent rechecking branches
        @already_searched[sha] = true

        array = []
        if (sha)
          o = get_raw_object_by_sha1(sha)
          if o.type == :tag
            commit_sha = get_object_by_sha1(sha).object
            c = get_object_by_sha1(commit_sha)
          else
            c = GitObject.from_raw(o)
          end

          return [] if c.type != :commit

          add_sha = true

          if opts[:since] && opts[:since].is_a?(Time) && (opts[:since] > c.committer.date)
            add_sha = false
          end
          if opts[:until] && opts[:until].is_a?(Time) && (opts[:until] < c.committer.date)
            add_sha = false
          end

          # follow all parents unless '--first-parent' is specified #
          subarray = []

          if !c.parent.first && opts[:path_limiter]  # check for the last commit
            add_sha = false
          end

          if (!opts[:max_count] || ((array.size + total_size) < opts[:max_count]))

            if !opts[:path_limiter]
              output = c.raw_log(sha)
              array << [sha, output, c.committer.date]
            end

            if (opts[:max_count] && (array.size + total_size) >= opts[:max_count])
              return array
            end

            c.parent.each do |psha|
              if psha && !files_changed?(c.tree, get_object_by_sha1(psha).tree,
                                        opts[:path_limiter])
                add_sha = false
              end
              subarray += walk_log(psha, opts, (array.size + total_size))
              next if opts[:first_parent]
            end

            if opts[:path_limiter] && add_sha
              output = c.raw_log(sha)
              array << [sha, output, c.committer.date]
            end

            if add_sha
              array += subarray
            end
          end

        end

        array
      end

      def diff(commit1, commit2, options = {})
        patch = ''

        commit_obj1 = get_object_by_sha1(commit1)
        tree1 = commit_obj1.tree
        if commit2
          tree2 = get_object_by_sha1(commit2).tree
        else
          tree2 = get_object_by_sha1(commit_obj1.parent.first).tree
        end

        qdiff = quick_diff(tree1, tree2)

        qdiff.sort.each do |diff_arr|
          path, status, treeSHA1, treeSHA2 = *diff_arr
          format, lines, output = :unified, 3, ''
          file_length_difference = 0

          fileA = treeSHA1 ? cat_file(treeSHA1) : ''
          fileB = treeSHA2 ? cat_file(treeSHA2) : ''

          sha1 = treeSHA1 || '0000000000000000000000000000000000000000'
          sha2 = treeSHA2 || '0000000000000000000000000000000000000000'

          data_old = fileA.split(/\n/).map! { |e| e.chomp }
          data_new = fileB.split(/\n/).map! { |e| e.chomp }

          diffs = Difference::LCS.diff(data_old, data_new)
          next if diffs.empty?

          a_path = "a/#{path.gsub('./', '')}"
          b_path = "b/#{path.gsub('./', '')}"

          header = "diff --git #{a_path} #{b_path}"
          if options[:full_index]
            header << "\n" + 'index ' + sha1 + '..' + sha2
            header << ' 100644' if treeSHA2 # hard coding this because i don't think we use it
          else
            header << "\n" + 'index ' + sha1[0,7] + '..' + sha2[0,7]
            header << ' 100644' if treeSHA2 # hard coding this because i don't think we use it
          end
          header << "\n--- " + (treeSHA1 ? a_path : '/dev/null')
          header << "\n+++ " + (treeSHA2 ? b_path : '/dev/null')
          header += "\n"

          oldhunk = hunk = nil

          diffs.each do |piece|
            begin
              hunk = Difference::LCS::Hunk.new(data_old, data_new, piece, lines, file_length_difference)
              file_length_difference = hunk.file_length_difference

              next unless oldhunk

              if lines > 0 && hunk.overlaps?(oldhunk)
                hunk.unshift(oldhunk)
              else
                output << oldhunk.diff(format)
              end
            ensure
              oldhunk = hunk
              output << "\n"
            end
          end

          output << oldhunk.diff(format)
          output << "\n"

          patch << header + output.lstrip
        end
        patch
      rescue
        '' # one of the trees was bad or lcs isn't there - no diff
      end

      # takes 2 tree shas and recursively walks them to find out what
      # files or directories have been modified in them and returns an
      # array of changes
      # [ [full_path, 'added', tree1_hash, nil],
      #   [full_path, 'removed', nil, tree2_hash],
      #   [full_path, 'modified', tree1_hash, tree2_hash]
      #  ]
      def quick_diff(tree1, tree2, path = '.', recurse = true)
        # handle empty trees
        changed = []
        return changed if tree1 == tree2

        t1 = list_tree(tree1) if tree1
        t2 = list_tree(tree2) if tree2

        # finding files that are different
        t1['blob'].each do |file, hsh|
          t2_file = t2['blob'][file] rescue nil
          full = File.join(path, file)
          if !t2_file
            changed << [full, 'added', hsh[:sha], nil]      # not in parent
          elsif (hsh[:sha] != t2_file[:sha])
            changed << [full, 'modified', hsh[:sha], t2_file[:sha]]   # file changed
          end
        end if t1
        t2['blob'].each do |file, hsh|
          if !t1 || !t1['blob'][file]
            changed << [File.join(path, file), 'removed', nil, hsh[:sha]]
          end
        end if t2

        t1['tree'].each do |dir, hsh|
          t2_tree = t2['tree'][dir] rescue nil
          full = File.join(path, dir)
          if !t2_tree
            if recurse
              changed += quick_diff(hsh[:sha], nil, full, true)
            else
              changed << [full, 'added', hsh[:sha], nil]      # not in parent
            end
          elsif (hsh[:sha] != t2_tree[:sha])
            if recurse
              changed += quick_diff(hsh[:sha], t2_tree[:sha], full, true)
            else
              changed << [full, 'modified', hsh[:sha], t2_tree[:sha]]   # file changed
            end
          end
        end if t1
        t2['tree'].each do |dir, hsh|
          t1_tree = t1['tree'][dir] rescue nil
          full = File.join(path, dir)
          if !t1_tree
            if recurse
              changed += quick_diff(nil, hsh[:sha], full, true)
            else
              changed << [full, 'removed', nil, hsh[:sha]]
            end
          end
        end if t2

        changed
      end

      # returns true if the files in path_limiter were changed, or no path limiter
      # used by the log() function when passed with a path_limiter
      def files_changed?(tree_sha1, tree_sha2, path_limiter = nil)
        if path_limiter
          mod = quick_diff(tree_sha1, tree_sha2)
          files = mod.map { |c| c.first }
          path_limiter.to_a.each do |filepath|
            if files.include?(filepath)
              return true
            end
          end
          return false
        end
        true
      end

      def get_subtree(commit_sha, path)
        tree_sha = get_object_by_sha1(commit_sha).tree

        if path && !(path == '' || path == '.' || path == './')
          paths = path.split('/')
          paths.each do |pathname|
            tree = get_object_by_sha1(tree_sha)
            if entry = tree.entry.select { |e| e.name == pathname }.first
              tree_sha = entry.sha1 rescue nil
            else
              return false
            end
          end
        end

        tree_sha
      end

      def blame_tree(commit_sha, path)
        # find subtree
        tree_sha = get_subtree(commit_sha, path)
        return {} if !tree_sha

        looking_for = []
        get_object_by_sha1(tree_sha).entry.each do |e|
          looking_for << File.join('.', e.name)
        end

        @already_searched = {}
        commits = look_for_commits(commit_sha, path, looking_for)

        # cleaning up array
        arr = {}
        commits.each do |commit_array|
          key = commit_array[0].gsub('./', '')
          arr[key] = commit_array[1]
        end
        arr
      end

      def look_for_commits(commit_sha, path, looking_for, options = {})
        return [] if @already_searched[commit_sha] # to prevent rechecking branches

        @already_searched[commit_sha] = true

        commit = get_object_by_sha1(commit_sha)
        tree_sha = get_subtree(commit_sha, path)

        found_data = []

        # at the beginning of the branch
        if commit.parent.size == 0
          looking_for.each do |search|
            # prevents the rare case of multiple branch starting points with
            # files that have never changed
            if found_data.assoc(search)
              found_data << [search, commit_sha]
            end
          end
          return found_data
        end

        # go through the parents recursively, looking for somewhere this has been changed
        commit.parent.each do |pc|
          diff = quick_diff(tree_sha, get_subtree(pc, path), '.', false)

          # remove anything found
          looking_for.each do |search|
            if match = diff.assoc(search)
              found_data << [search, commit_sha, match]
              looking_for.delete(search)
            end
          end

          if looking_for.size <= 0  # we're done
            return found_data
          end

          found_data += look_for_commits(pc, path, looking_for)  # recurse into parent
          return found_data if options[:first_parent]
        end

        ## TODO : find most recent commit with change in any parent
        found_data
      end

      # initialize a git repository
      def self.init(dir, bare = true)

        FileUtils.mkdir_p(dir) if !File.exists?(dir)

        FileUtils.cd(dir) do
          if(File.exists?('objects'))
            return false # already initialized
          else
            # initialize directory
            create_initial_config(bare)
            FileUtils.mkdir_p('refs/heads')
            FileUtils.mkdir_p('refs/tags')
            FileUtils.mkdir_p('objects/info')
            FileUtils.mkdir_p('objects/pack')
            FileUtils.mkdir_p('branches')
            add_file('description', 'Unnamed repository; edit this file to name it for gitweb.')
            add_file('HEAD', "ref: refs/heads/master\n")
            FileUtils.mkdir_p('hooks')
            FileUtils.cd('hooks') do
              add_file('applypatch-msg', '# add shell script and make executable to enable')
              add_file('post-commit', '# add shell script and make executable to enable')
              add_file('post-receive', '# add shell script and make executable to enable')
              add_file('post-update', '# add shell script and make executable to enable')
              add_file('pre-applypatch', '# add shell script and make executable to enable')
              add_file('pre-commit', '# add shell script and make executable to enable')
              add_file('pre-rebase', '# add shell script and make executable to enable')
              add_file('update', '# add shell script and make executable to enable')
            end
            FileUtils.mkdir_p('info')
            add_file('info/exclude', "# *.[oa]\n# *~")
          end
        end
      end

      def self.create_initial_config(bare = false)
        bare ? bare_status = 'true' : bare_status = 'false'
        config = "[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n\tbare = #{bare_status}\n\tlogallrefupdates = true"
        add_file('config', config)
      end

      def self.add_file(name, contents)
        File.open(name, 'w') do |f|
          f.write contents
        end
      end

      def close
        @packs.each do |pack|
          pack.close
        end if @packs
      end

      protected

        def git_path(path)
          return "#@git_dir/#{path}"
        end

      private

        def initloose
          @loaded = []
          @loose = []
          load_loose(git_path('objects'))
          load_alternate_loose(git_path('objects'))
          @loose
        end

        def each_alternate_path(path)
          alt = File.join(path, 'info/alternates')
          return if !File.exists?(alt)

          File.readlines(alt).each do |line|
            path = line.chomp
            if path[0, 2] == '..'
              yield File.expand_path(File.join(@git_dir, 'objects', path))

              # XXX this is here for backward compatibility with grit < 2.3.0
              # relative alternate objects paths are expanded relative to the
              # objects directory, not the git repository directory.
              yield File.expand_path(File.join(@git_dir, path))
            else
              yield path
            end
          end
        end

        def load_alternate_loose(pathname)
          # load alternate loose, too
          each_alternate_path pathname do |path|
            next if @loaded.include?(path)
            next if !File.exist?(path)
            load_loose(path)
            load_alternate_loose(path)
          end
        end

        def load_loose(path)
          @loaded << path
          return if !File.exists?(path)
          @loose << Grit::GitRuby::Internal::LooseStorage.new(path)
        end

        def initpacks
          close
          @loaded_packs = []
          @packs = []
          load_packs(git_path("objects/pack"))
          load_alternate_packs(git_path('objects'))
          @packs
        end

        def load_alternate_packs(pathname)
          each_alternate_path pathname do |path|
            full_pack = File.join(path, 'pack')
            next if @loaded_packs.include?(full_pack)
            load_packs(full_pack)
            load_alternate_packs(path)
          end
        end

        def load_packs(path)
          @loaded_packs << path
          return if !File.exists?(path)
           Dir.open(path) do |dir|
            dir.each do |entry|
              next if !(entry =~ /\.pack$/i)
              pack = Grit::GitRuby::Internal::PackStorage.new(File.join(path,entry))
              if @options[:map_packfile]
                pack.cache_objects
              end
              @packs << pack
            end
          end
        end

    end

  end
end
