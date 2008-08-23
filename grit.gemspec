Gem::Specification.new do |s|
  s.name     = "grit"
  s.version  = "0.9.3"
  s.date     = "2008-04-24"
  s.summary  = "Object model interface to a git repo"
  s.email    = "tom@rubyisawesome.com"
  s.homepage = "http://github.com/schacon/grit"
  s.description = "Grit is a Ruby library for extracting information from a git repository in and object oriented manner."
  s.has_rdoc = true
  s.authors  = ["Tom Preston-Werner", "Scott Chacon"]
  s.files    = ["History.txt", 
		"Manifest.txt", 
		"README.txt", 
		"Rakefile", 
		"grit.gemspec", 
		"lib/grit/actor.rb", 
		"lib/grit/blob.rb", 
		"lib/grit/commit.rb", 
		"lib/grit/commit_stats.rb", 
		"lib/grit/config.rb", 
		"lib/grit/diff.rb", 
		"lib/grit/errors.rb", 
		"lib/grit/git-ruby/commit_db.rb", 
		"lib/grit/git-ruby/file_index.rb", 
		"lib/grit/git-ruby/git_object.rb", 
		"lib/grit/git-ruby/internal", 
		"lib/grit/git-ruby/internal/loose.rb", 
		"lib/grit/git-ruby/internal/mmap.rb", 
		"lib/grit/git-ruby/internal/pack.rb", 
		"lib/grit/git-ruby/internal/raw_object.rb", 
		"lib/grit/git-ruby/object.rb", 
		"lib/grit/git-ruby/repository.rb", 
		"lib/grit/git-ruby.rb", 
		"lib/grit/git.rb", 
		"lib/grit/head.rb", 
		"lib/grit/index.rb", 
		"lib/grit/lazy.rb", 
		"lib/grit/ref.rb", 
		"lib/grit/repo.rb", 
		"lib/grit/status.rb", 
		"lib/grit/tag.rb", 
		"lib/grit/tree.rb", 
		"lib/grit.rb"]
  s.test_files = ["test/test_actor.rb", 
      "test/test_blob.rb", "test/test_commit.rb", 
      "test/test_config.rb", 
      "test/test_diff.rb", 
      "test/test_git.rb", 
      "test/test_grit.rb", 
      "test/test_head.rb", 
      "test/test_real.rb", 
      "test/test_reality.rb",
      "test/test_remote.rb", 
      "test/test_repo.rb", 
      "test/test_tag.rb", 
      "test/test_tree.rb"]
  s.rdoc_options = ["--main", "README.txt"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.add_dependency("mime-types", ["> 0.0.0"])
  s.add_dependency("open4", ["> 0.0.0"])
end
