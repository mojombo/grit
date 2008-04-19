require 'grit/git-ruby/repository'

module Grit
  
  # the functions in this module intercept the calls to git binary
  # made buy the grit objects and attempts to run them in pure ruby
  # if it will be faster, or if the git binary is not available (!!TODO!!)
  module GitRuby
    
    class << self
      attr_accessor :cache_client
    end
    self.cache_client = false
    
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
    def ls_tree(options, treeish, paths = [])
      return ruby_git.ls_tree(rev_parse({}, treeish), paths)
    end

    def rev_list(options, ref)
      return ruby_git.rev_list(rev_parse({}, ref), options)      
    end

    def log(options, ref)
      options[:max_count] = 30 if !options[:max_count]
      return ruby_git.rev_list(rev_parse({}, ref), options)      
    end
    
        
    def rev_parse(options, string)      
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
    
    def ruby_git
      @ruby_git_repo ||= Repository.new(@git_dir, GitRuby.cache_client)
    end
    
  end
end