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
    def ls_tree(options, treeish, paths = [])
      return ruby_git_dir.list_tree(revparse(treeish), paths)
    end
        
    def revparse(string)
      if /\w{40}/.match(string)  # passing in a sha - just no-op it
        return string
      end
            
      head = File.join(@git_dir, 'refs', 'heads', string)
      return File.read(head).chomp if File.file?(head)

      head = File.join(@git_dir, 'refs', 'remotes', string)
      return File.read(head).chomp if File.file?(head)
      
      head = File.join(@git_dir, 'refs', 'tags', string)
      return File.read(head).chomp if File.file?(head)
      
      ## !! check packed-refs file, too !! 
      ## !! more - partials and such !!
      
      puts "AH"
      # revert to calling git
      return method_missing('rev-parse', {}, string)
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