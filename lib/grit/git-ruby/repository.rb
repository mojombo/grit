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
      
      attr_accessor :cache_ls_tree, :use_cache
      
      def initialize(git_dir, use_cache = false)
        clear_cache()
        @use_cache = use_cache
        
        @git_dir = git_dir
      end
      
      def loose
        @loose ||= Grit::GitRuby::Internal::LooseStorage.new(git_path("objects"))
      end
      
      def packs
        @packs ||= initpacks
      end

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

      def object(sha)
        o = get_raw_object_by_sha1(sha)
        c = Grit::GitRuby::Object.from_raw(o)
      end

      def cat_file_type(sha)
        get_raw_object_by_sha1(sha).type
      end
                  
      def cat_file_size(sha)
        get_raw_object_by_sha1(sha).content.size
      end
      
      def cat_file(sha)
        o = get_raw_object_by_sha1(sha)
        object(sha).raw_content
      end
      
      def log(sha, options = {})
        @already_searched = {}
        @use_cache = true
        walk_log(sha, options)
      end

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
            if psha && !files_changed?(c.tree, object(psha).tree, opts[:path_limiter])
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
      
      # returns true if the files in path_limiter were changed, or no path limiter
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
      
      def last_commits(commit_sha, looking_for)        
        # swap caching temporarily - we have to do this because the algorithm 
        # that dumb scott used ls-tree's each tree twice, which is 90% of the
        # time this takes, so caching those hits halves the time this takes to run
        # but, it does take up memory, so if you don't want it, i clear it later
        old_use_cache = @use_cache 
        @use_cache = true

          @already_searched = {}
          data = look_for_commits(commit_sha, looking_for)

        @use_cache = old_use_cache
        clear_cache if !old_use_cache 

        data
      end
    
      def clear_cache
        @cache_ls_tree = {}
      end
      
      def look_for_commits(commit_sha, looking_for)        
        return [] if @already_searched[commit_sha] # to prevent rechecking branches
        @already_searched[commit_sha] = true
        
        commit = object(commit_sha)
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
          diff = quick_diff(tree_sha, object(pc).tree, '.', false)
          
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
            
      def quick_diff(tree1, tree2, path = '.', recurse = true)
        # handle empty trees
        changed = []

        t1 = ls_tree(tree1) if tree1
        t2 = ls_tree(tree2) if tree2

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
      
      def ls_tree(sha)
        return @cache_ls_tree[sha] if @cache_ls_tree[sha] && @use_cache
        
        data = {'blob' => {}, 'tree' => {}}
        self.object(sha).entry.each do |e|
          data[e.format_type][e.name] = {:mode => e.format_mode, :sha => e.sha1}
        end 
        @cache_ls_tree[sha] = data             
      end
            
      def get_object_by_sha1(sha1)
        r = get_raw_object_by_sha1(sha1)
        return nil if !r
        Object.from_raw(r, self)
      end
      
      def put_raw_object(content, type)
        loose.put_raw_object(content, type)
      end
      
      def object_exists?(sha1)
        sha_hex = [sha1].pack("H*")
        return true if in_packs?(sha_hex)
        return true if in_loose?(sha_hex)
        initpacks
        return true if in_packs?(sha_hex) #maybe the object got packed in the meantime
        false
      end
      
      def in_packs?(sha_hex)
        # try packs
        packs.each do |pack|
          return true if pack[sha_hex]
        end
        false
      end
      
      def in_loose?(sha_hex)
        return true if loose[sha_hex]
        false
      end
      
      def get_raw_object_by_sha1(sha1)
        sha1 = [sha1].pack("H*")
        
        # try packs
        packs.each do |pack|
          o = pack[sha1]
          return o if o
        end
        
        # try loose storage
        o = loose[sha1]
        return o if o

        # try packs again, maybe the object got packed in the meantime
        initpacks
        packs.each do |pack|
          o = pack[sha1]
          return o if o
        end

        raise NoSuchShaFound
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
          if File.exists?(git_path("objects/pack"))
            Dir.open(git_path("objects/pack/")) do |dir|
              dir.each do |entry|
                if entry =~ /\.pack$/i
                  @packs << Grit::GitRuby::Internal::PackStorage.new(git_path("objects/pack/" \
                                                                    + entry))
                end
              end
            end
          end
          @packs
        end
      
    end
    
  end
end
