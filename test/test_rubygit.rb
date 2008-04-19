require File.dirname(__FILE__) + '/helper'

class TestRubyGit < Test::Unit::TestCase
  
  def setup
    @git = Git.new(File.join(File.dirname(__FILE__), *%w[dot_git]))
    @commit_sha = '5e3ee1198672257164ce3fe31dea3e40848e68d5'
    @tree_sha = 'cd7422af5a2e0fff3e94d6fb1a8fff03b2841881'
    @blob_sha = '4232d073306f01cf0b895864e5a5cfad7dd76fce'
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

  def test_ls_tree_treeish
    out = @git.ls_tree({}, 'testing')
    assert_equal out, fixture('cat_file_tree_ruby').chomp
  end
  
  def test_ls_tree_paths
    paths = ['History.txt', 'lib']
    out = @git.ls_tree({}, @tree_sha, paths)
    assert_equal out, fixture('ls_tree_paths_ruby').chomp
  end
  
  
  def test_file_type
    out = @git.file_type(@tree_sha).to_s
    assert_equal 'tree', out
    out = @git.file_type(@blob_sha).to_s
    assert_equal 'blob', out
    out = @git.file_type(@commit_sha).to_s
    assert_equal 'commit', out
  end
  
end
