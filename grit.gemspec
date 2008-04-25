Gem::Specification.new do |s|
  s.name = "grit"
  s.version = "0.8.1"
  s.date = "2008-04-24"
  s.summary = "Object model interface to a git repo"
  s.email = "tom@rubyisawesome.com"
  s.homepage = "http://github.com/mojombo/grit"
  s.description = "Grit is a Ruby library for extracting information from a git repository in and object oriented manner."
  s.has_rdoc = true
  s.authors = ["Tom Preston-Werner"]
  s.files = ["History.txt", "Manifest.txt", "README.txt", "Rakefile", "grit.gemspec", "lib/grit.rb", "lib/grit/actor.rb", "lib/grit/blob.rb", "lib/grit/commit.rb", "lib/grit/config.rb", "lib/grit/diff.rb", "lib/grit/errors.rb", "lib/grit/git.rb", "lib/grit/head.rb", "lib/grit/lazy.rb", "lib/grit/repo.rb", "lib/grit/tag.rb", "lib/grit/tree.rb", "test/fixtures/blame", "test/fixtures/cat_file_blob", "test/fixtures/cat_file_blob_size", "test/fixtures/diff_2", "test/fixtures/diff_2f", "test/fixtures/diff_f", "test/fixtures/diff_i", "test/fixtures/diff_mode_only", "test/fixtures/diff_new_mode", "test/fixtures/diff_p", "test/fixtures/for_each_ref", "test/fixtures/for_each_ref_tags", "test/fixtures/ls_tree_a", "test/fixtures/ls_tree_b", "test/fixtures/ls_tree_commit", "test/fixtures/rev_list", "test/fixtures/rev_list_count", "test/fixtures/rev_list_single", "test/fixtures/rev_parse", "test/fixtures/show_empty_commit", "test/fixtures/simple_config", "test/helper.rb", "test/profile.rb", "test/suite.rb", "test/test_actor.rb", "test/test_blob.rb", "test/test_commit.rb", "test/test_config.rb", "test/test_diff.rb", "test/test_git.rb", "test/test_head.rb", "test/test_reality.rb", "test/test_repo.rb", "test/test_tag.rb", "test/test_tree.rb", "test/test_real.rb"]
  s.test_files = ["test/test_actor.rb", "test/test_blob.rb", "test/test_commit.rb", "test/test_config.rb", "test/test_diff.rb", "test/test_git.rb", "test/test_head.rb", "test/test_real.rb", "test/test_reality.rb", "test/test_repo.rb", "test/test_tag.rb", "test/test_tree.rb"]
  s.rdoc_options = ["--main", "README.txt"]
  s.extra_rdoc_files = ["History.txt", "Manifest.txt", "README.txt"]
  s.add_dependency("mime-types", ["> 0.0.0"])
end