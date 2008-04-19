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
require 'grit/git-ruby/object'

module Grit
  module GitRuby
    class Repository
      
      class NoSuchShaFound < StandardError
      end
      
      attr_accessor :git_dir, :cache
      
      def initialize(git_dir, cache_client = nil)
        @cache = cache_client || false  
        @git_dir = git_dir
      end
      
      # returns the loose objects object lazily
      def loose
        @loose ||= Grit::GitRuby::Internal::LooseStorage.new(git_path("objects"))
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
        key = 'rawobject:' + sha1o
        #puts
        #puts key
        if @cache && (cacheobj = @cache.get(key, false))
        #  puts 'begin'
        #  puts cacheobj if cacheobj
        #  puts 'end'
          return cacheobj
        end
        
        sha1 = [sha1o.chomp].pack("H*")

        # try packs
        packs.each do |pack|
          o = pack[sha1]
          return cached(key, o) if o
        end

        # try loose storage
        o = loose[sha1]
        return cached(key, o) if o

        # try packs again, maybe the object got packed in the meantime
        initpacks
        packs.each do |pack|
          o = pack[sha1]
          return cached(key, o) if o
        end

        puts "*#{sha1o}*"
        raise NoSuchShaFound
      end

      def cached(key, object)
        @cache.set(key, object, 0, false) if @cache
        object
      end
      
      # returns GitRuby object of any type given a SHA1
      def get_object_by_sha1(sha1)
        r = get_raw_object_by_sha1(sha1)
        return nil if !r
        Object.from_raw(r, self)
      end
      
      # writes a raw object into the git repo
      def put_raw_object(content, type)
        loose.put_raw_object(content, type)
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
        return true if loose[sha_hex]
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
        o = get_raw_object_by_sha1(sha)
        get_object_by_sha1(sha).raw_content
      end
      
      # returns a 2-d hash of the tree
      # ['blob']['FILENAME'] = {:mode => '100644', :sha => SHA}
      # ['tree']['DIRNAME'] = {:mode => '040000', :sha => SHA}
      def list_tree(sha)        
        data = {'blob' => {}, 'tree' => {}}
        get_object_by_sha1(sha).entry.each do |e|
          data[e.format_type][e.name] = {:mode => e.format_mode, :sha => e.sha1}
        end 
      end
      
      # returns the raw (cat-file) output for a tree
      # if given a commit sha, it will print the tree of that commit
      # if given a path limiter array, it will limit the output to those
      def ls_tree(sha, paths = [])
        o = get_raw_object_by_sha1(sha)
        if o.type == :commit
          tree = cat_file(get_object_by_sha1(sha).tree)
        else
          tree = cat_file(sha)
        end
        
        if paths.size > 0
          tree = tree.split("\n").select { |line| paths.include?(line.split("\t")[1]) }.join("\n")
        end
        tree 
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

      def rev_list(sha, options)
        log = log(sha, options)
        if options[:pretty] = 'raw'
          log.map {|k, v| v.chomp }.join('')
        else
          log.map {|k, v| k }.join('')
        end
      end
      
      # called by log() to recursively walk the tree
      def walk_log(sha, opts)
        return [] if @already_searched[sha] # to prevent rechecking branches
        @already_searched[sha] = true
        
        array = []          
        if (sha)
          o = get_raw_object_by_sha1(sha)
          c = Grit::GitRuby::Object.from_raw(o)

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
          
          c.parent.each do |psha|
            if psha && !files_changed?(c.tree, get_object_by_sha1(psha).tree, opts[:path_limiter])
              add_sha = false 
            end
            subarray += walk_log(psha, opts) 
            next if opts[:first_parent]
          end
          
          if (!opts[:max_count] || (array.size < opts[:max_count]))
            if add_sha
              output = "commit #{sha}\n"
              output += o.content + "\n\n"
              array << [sha, output]
            end          
            array += subarray
          end
                                
        end
        
        array
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
           if !t1['blob'][file]
             changed << [File.join(path, file), 'removed', nil, hsh[:sha]]
           end if t1
         end if t2

         t1['tree'].each do |dir, hsh|
           t2_tree = t2['tree'][dir] rescue nil
           full = File.join(path, dir)
           if !t2_tree
             if recurse
               changed += quick_diff(hsh[:sha], nil, full) 
             else
               changed << [full, 'added', hsh[:sha], nil]      # not in parent
             end
           elsif (hsh[:sha] != t2_tree[:sha])
             if recurse
               changed += quick_diff(hsh[:sha], t2_tree[:sha], full) 
             else
               changed << [full, 'modified', hsh[:sha], t2_tree[:sha]]   # file changed
             end
           end
         end if t1
         t2['tree'].each do |dir, hsh|
           t1_tree = t2['tree'][dir] rescue nil
           full = File.join(path, dir)
           if !t1_tree
             if recurse
               changed += quick_diff(nil, hsh[:sha], full) 
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
        
            
      ## EXPERIMENTAL - the following are trying to develop a fast blame-tree ##
      
      # this is slighltly broken right now, so don't use it
      # it returns a list of the last commit for each file in the tree
      # of the commit you pass in, but I don't think the looking_for 
      # works yet, so it will only work from the root, not a subtree
      def blame_tree(commit_sha, looking_for)        
        # swap caching temporarily - we have to do this because the algorithm 
        # that dumb scott used ls-tree's each tree twice, which is 90% of the
        # time this takes, so caching those hits halves the time this takes to run
        # but, it does take up memory, so if you don't want it, i clear it later
        @already_searched = {}
        look_for_commits(commit_sha, looking_for)
      end
    
      def look_for_commits(commit_sha, looking_for)        
        return [] if @already_searched[commit_sha] # to prevent rechecking branches
        @already_searched[commit_sha] = true
        
        commit = get_object_by_sha1(commit_sha)
        tree_sha = commit.tree
        
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
          diff = quick_diff(tree_sha, get_object_by_sha1(pc).tree, '.', false)
          
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

          found_data += look_for_commits(pc, looking_for)  # recurse into parent
        end
        
        ## TODO : find most recent commit with change in any parent
        found_data
      end
      
      protected

        def git_path(path)
          return "#@git_dir/#{path}"
        end

      private 
      
        def initpacks
          @packs.each do |pack|
            pack.close
          end if @packs
          
          @packs = []
          if f = File.exists?(git_path("objects/pack"))
            Dir.open(git_path("objects/pack/")) do |dir|
              dir.each do |entry|
                if entry =~ /\.pack$/i
                  @packs << Grit::GitRuby::Internal::PackStorage.new(git_path("objects/pack/" \
                                                                    + entry))
                #elsif entry =~ /\.idx$/i
                #  puts Internal::PackStorage.get_shas(git_path("objects/pack/" \
                #                                                    + entry))
                end
                
              end
            end
          end
          @packs
        end
      
    end
    
  end
end
