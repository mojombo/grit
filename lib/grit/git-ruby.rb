require 'grit/git-ruby/repository'

module Grit
  
  # the functions in this module intercept the calls to git binary
  # made buy the grit objects and attempts to run them in pure ruby
  # if it will be faster, or if the git binary is not available (!!TODO!!)
  module GitRuby
    
    attr_accessor :ruby_git_repo
    
    def cat_file(options, ref)
      if options[:t]
        file_type(ref)
      elsif options[:s]
        file_size(ref)
      elsif options[:p]
        ruby_git.cat_file(ref)
      end
    end
    
    # lib/grit/tree.rb:16:      output = repo.git.ls_tree({}, treeish, *paths)
    def ls_tree(options, treeish, *paths)
      sha = rev_parse({}, treeish)
      ruby_git.ls_tree(sha, paths.flatten)
    end

    # git diff --full-index 'ec037431382e83c3e95d4f2b3d145afbac8ea55d' 'f1ec1aea10986159456846b8a05615b87828d6c6'
    def diff(options, sha1, sha2)
      ruby_git.diff(sha1, sha2, options)
    end
    
    def rev_list(options, ref)
      options.delete(:skip) if options[:skip].to_i == 0
      allowed_options = [:max_count, :since, :until, :pretty]  # this is all I can do right now
      if (options.keys - allowed_options).size > 0
        return method_missing('rev-list', options, ref)
      else
        return ruby_git.rev_list(rev_parse({}, ref), options)      
      end
    end
    
    def rev_parse(options, string)      
      if string =~ /\.\./
        (sha1, sha2) = string.split('..')
        return [rev_parse({}, sha1), rev_parse({}, sha2)]
      end
      
      if /\w{40}/.match(string)  # passing in a sha - just no-op it
        return string.chomp
      end

      head = File.join(@git_dir, 'refs', 'heads', string)
      return File.read(head).chomp if File.file?(head)

      head = File.join(@git_dir, 'refs', 'remotes', string)
      return File.read(head).chomp if File.file?(head)
      
      head = File.join(@git_dir, 'refs', 'tags', string)
      return File.read(head).chomp if File.file?(head)
      
      ## !! check packed-refs file, too !! 
      ## !! more - partials and such !!
      
      # revert to calling git - grr
      return method_missing('rev-parse', {}, string)
    end
    
    def file_size(ref)
      ruby_git.cat_file_size(ref).to_s
    end
    
    def file_type(ref)
      ruby_git.cat_file_type(ref)
    end
    
    def blame_tree(commit, path = nil)
      #temp = Repository.new(@git_dir, :map_packfile => true)
      #temp.blame_tree(rev_parse({}, commit), path)
      
      tree_sha = ruby_git.get_subtree(rev_parse({}, commit), path)
      puts tree_sha
      
      call = ''
      looking_for = []
      ruby_git.get_object_by_sha1(tree_sha).entry.each do |e|
        if path && !(path == '' || path == '.' || path == './')
          file = File.join(path, e.name)
        else
          file = e.name
        end
        looking_for << file
        call += "#{Git.git_binary} --git-dir='#{self.git_dir}' log --pretty=\"raw\" --max-count=1 -- #{file}\n"
      end
      
      puts call if Grit.debug
      response = wild_sh(call)
      puts response if Grit.debug
      response
            
      commits = Grit::Commit.list_from_string(@git_dir, response)

      blame = {}
      looking_for.each_with_index do |name, index|
        blame[name] = commits[index]
      end
      
      blame
    end
    
    def ruby_git
      @ruby_git_repo ||= Repository.new(@git_dir)
    end
    
    
    # TODO     
    # git grep -n 'foo' 'master'
    # git log --pretty='raw' --max-count='1' 'master' -- 'LICENSE'
    # git log --pretty='raw' --max-count='1' 'master' -- 'test'
    
  end
end