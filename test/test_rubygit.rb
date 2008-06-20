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

  def test_ls_tree_paths_multi_single
    paths = ['lib/grit.rb']
    out = @git.ls_tree({}, @tree_sha, paths)
    assert_equal out, '100644 blob 6afcf64c80da8253fa47228eb09bc0eea217e5d1	lib/grit.rb'
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
    assert_equal out, fixture('rev_list_lines').chomp
  end
  
=begin
  def test_ls_tree_grit_tree
    paths = ['lib/grit.rb']
    @repo = Grit::Repo.new('~/projects/github')    
    paths = ['app/models/event.rb']
    puts out = @repo.git.ls_tree({}, 'master', ['app/models/event.rb'])
    puts out = @repo.tree('master', paths).contents
    assert_equal out, '100644 blob 6afcf64c80da8253fa47228eb09bc0eea217e5d1	lib/grit.rb'
  end
=end

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
  
end
