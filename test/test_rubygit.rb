require File.dirname(__FILE__) + '/helper'
require 'tempfile'

class TestRubyGit < Test::Unit::TestCase

  def setup
    @git = Git.new(File.join(File.dirname(__FILE__), *%w[dot_git]))
    @commit_sha = '5e3ee1198672257164ce3fe31dea3e40848e68d5'
    @tree_sha = 'cd7422af5a2e0fff3e94d6fb1a8fff03b2841881'
    @blob_sha = '4232d073306f01cf0b895864e5a5cfad7dd76fce'
  end

  def test_init_gitdir
    tf = Tempfile.new('gitdir')
    temppath = tf.path
    tf.unlink

    git = Git.new(temppath)
    git.init({})
    assert File.exists?(File.join(temppath, 'config'))
  end

  def test_log_merge
    c1 = '420eac97a826bfac8724b6b0eef35c20922124b7'
    c2 = '30e367cef2203eba2b341dc9050993b06fd1e108'
    out = @git.rev_list({:pretty => 'raw', :max_count => 10}, 'master')
    assert_match "commit #{c1}", out
    assert_match "commit #{c2}", out
  end

  def test_log_max_count
    out = @git.rev_list({:max_count => 10}, 'master')
    assert_equal 10, out.split("\n").size
  end

  def test_diff
    commit1 = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    commit2 = '420eac97a826bfac8724b6b0eef35c20922124b7'
    out = @git.diff({}, commit1, commit2)
    assert_match 'index 6afcf64..9e78ddf 100644', out
  end

  def test_diff_single
    commit1 = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    out = @git.diff({}, commit1, nil)
    assert_match 'index ad42ff5..aa50f09 100644', out
  end

  def test_diff_full
    commit1 = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    commit2 = '420eac97a826bfac8724b6b0eef35c20922124b7'
    out = @git.diff({:full_index => true}, commit1, commit2)
    assert_match 'index 6afcf64c80da8253fa47228eb09bc0eea217e5d1..9e78ddfaabf79f8314cc9a53a2f59775aee06bd7', out
  end

  def test_diff_add
    commit1 = 'c9cf68fc61bd2634e90a4f6a12d88744e6297c4e'
    commit2 = '7a8d32cb18a0ba2ff8bf86cadacc3fd2816da219'
    out = @git.diff({}, commit1, commit2)
    assert_match "--- /dev/null\n+++ b/test/test_tag.rb", out
    assert_match "diff --git a/test/test_tag.rb b/test/test_tag.rb", out
    assert_match 'index 0000000..2e3b0cb', out
  end

  def test_diff_remove
    commit1 = 'c9cf68fc61bd2634e90a4f6a12d88744e6297c4e'
    commit2 = '7a8d32cb18a0ba2ff8bf86cadacc3fd2816da219'
    out = @git.diff({}, commit1, commit2)
    assert_match "--- a/test/fixtures/diff_2\n+++ /dev/null", out
    assert_match "diff --git a/test/fixtures/diff_2 b/test/fixtures/diff_2", out
    assert_match 'index 0000000..2e3b0cb', out
  end


  def test_cat_file_contents_commit
    out = @git.cat_file({:p => true}, @commit_sha)
    assert_equal out, fixture('cat_file_commit_ruby')
  end

  def test_cat_file_contents_tree
    out = @git.cat_file({:p => true}, @tree_sha)
    assert_equal out, fixture('cat_file_tree_ruby').chomp
  end

  def test_cat_file_contents_blob
    out = @git.cat_file({:p => true}, @blob_sha)
    assert_equal out, fixture('cat_file_blob_ruby')
  end

  def test_cat_file_size
    out = @git.cat_file({:s => true}, @tree_sha)
    assert_equal '252', out
  end

  def test_ls_tree
    out = @git.ls_tree({}, @tree_sha)
    assert_equal out, fixture('cat_file_tree_ruby').chomp
  end

  def test_ls_tree_with_blobs
    out = @git.ls_tree({}, @blob_sha)
    assert_equal out, nil
  end

  def test_ls_tree_treeish
    out = @git.ls_tree({}, 'testing')
    assert_equal out, fixture('cat_file_tree_ruby').chomp
  end

  def test_ls_tree_paths
    paths = ['History.txt', 'lib']
    out = @git.ls_tree({}, @tree_sha, paths)
    assert_equal out, fixture('ls_tree_paths_ruby').chomp
  end

  def test_ls_tree_paths_multi_single
    paths = ['lib/grit.rb']
    out = @git.ls_tree({}, @tree_sha, paths)
    assert_equal out, "100644 blob 6afcf64c80da8253fa47228eb09bc0eea217e5d1\tlib/grit.rb"
  end

  def test_ls_tree_recursive
    # this is the tree associated with @commit_sha, which we use in
    # the next test
    tree_sha = '77fc9894c0904279fde93adc9c0ba231515ce68a'

    out = @git.ls_tree({:r => true}, tree_sha)
    assert_equal out, fixture('ls_tree_recursive')
  end

  def test_ls_tree_recursive_with_a_commit
    out = @git.ls_tree({:r => true}, @commit_sha)
    assert_equal out, fixture('ls_tree_recursive')
  end

  def test_rev_list_pretty
    out = @git.rev_list({:pretty => 'raw'}, 'master')
    assert_equal out, fixture('rev_list_all')
  end

  def test_rev_list_raw_since
    out = @git.rev_list({:since => Time.at(1204644738)}, 'master')
    assert_match fixture('rev_list_since'), out  # I return slightly more for now
  end

  def test_rev_list_pretty_raw
    out = @git.rev_list({:pretty => 'raw'}, 'f1964ad1919180dd1d9eae9d21a1a1f68ac60e77')
    assert_match 'f1964ad1919180dd1d9eae9d21a1a1f68ac60e77', out
    assert_equal out.split("\n").size, 654
  end

  def test_rev_list
    out = @git.rev_list({}, 'master')
    assert_equal out, fixture('rev_list_lines')
  end

  def test_rev_list_range
    range = '30e367cef2203eba2b341dc9050993b06fd1e108..3fa4e130fa18c92e3030d4accb5d3e0cadd40157'
    out = @git.rev_list({}, range)
    assert_equal fixture('rev_list_range'), out
  end

  def test_ls_tree_paths_multi
    paths = ['History.txt', 'lib/grit.rb']
    out = @git.ls_tree({}, @tree_sha, paths)
    assert_equal out, fixture('ls_tree_paths_ruby_deep').chomp
  end

  def test_ls_tree_path
    paths = ['lib/']
    out = @git.ls_tree({}, @tree_sha, paths)
    assert_equal out, "100644 blob 6afcf64c80da8253fa47228eb09bc0eea217e5d1\tlib/grit.rb\n040000 tree 6244414d0229fb2bd58bc426a2afb5ba66773498\tlib/grit"
  end

  def test_ls_tree_path_deep
    paths = ['lib/grit/']
    out = @git.ls_tree({}, @tree_sha, paths)
    assert_equal out, fixture('ls_tree_subdir').chomp
  end

  def test_file_type
    out = @git.file_type(@tree_sha).to_s
    assert_equal 'tree', out
    out = @git.file_type(@blob_sha).to_s
    assert_equal 'blob', out
    out = @git.file_type(@commit_sha).to_s
    assert_equal 'commit', out
  end

  #def test_ls_tree_noexist
  #  puts out = @git.ls_tree({}, '6afcf64c80da8253fa47228eb09bc0eea217e5d0')
  #end


=begin
  def test_ls_tree_grit_tree
    paths = ['lib/grit.rb']
    @repo = Grit::Repo.new('~/projects/github')
    paths = ['app/models/event.rb']
    puts out = @repo.git.ls_tree({}, 'master', ['app/models/event.rb'])
    puts out = @repo.tree('master', paths).contents
    assert_equal out, '100644 blob 6afcf64c80da8253fa47228eb09bc0eea217e5d1 lib/grit.rb'
  end
=end

end
