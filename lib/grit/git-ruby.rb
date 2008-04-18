require 'grit/git-ruby/repository'

module Grit
  
  module GitRuby
    
    attr_accessor :ruby_gitdir
    
    # (raw) allowed_options = [:max_count, :skip, :since, :all]
    def cat_file(options, ref)
      if options[:t]
        file_type(ref)
        return 
      elsif options[:s]
        file_size(ref)
      elsif options[:p]
        ruby_git_dir.cat_file(ref)
      end
    end
    
    #   lib/grit/tree.rb:16:      output = repo.git.ls_tree({}, treeish, *paths)
    def ls_tree(options, treeish, paths)
      return ' hi '
    end
    
    def file_size(ref)
      ruby_git_dir.cat_file_size(ref).to_s
    end
    
    def file_type(ref)
      ruby_git_dir.cat_file_type(ref)
    end
    
    def ruby_git_dir
      @ruby_gitdir ||= Repository.new(@git_dir)
    end
    
  end
  
end