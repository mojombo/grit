require File.dirname(__FILE__) + '/helper'

class TestRepo < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end
  
  # new
  
  def test_new_should_raise_on_invalid_repo_location
    assert_raise(InvalidGitRepositoryError) do
      Repo.new("")
    end
  end
  
  # descriptions
  
  def test_description
    assert_equal "Grit is a ruby library for interfacing with git repositories.", @r.description
  end
  
  # heads
  
  def test_heads_should_return_array_of_head_objects
    @r.heads.each do |head|
      assert_equal Grit::Head, head.class
    end
  end
  
  def test_heads_should_populate_head_data
    Git.any_instance.expects(:for_each_ref).returns(fixture('for_each_ref'))
    
    head = @r.heads.first
    
    assert_equal 'master', head.name
    assert_equal '634396b2f541a9f2d58b00be1a07f0c358b999b3', head.commit.id
  end
  
  # branches
  
  def test_branches
    # same as heads
  end
  
  # commits
  
  def test_commits
    Git.any_instance.expects(:rev_list).returns(fixture('rev_list'))
    
    commits = @r.commits('master', 10)
    
    c = commits[0]
    assert_equal '4c8124ffcf4039d292442eeccabdeca5af5c5017', c.id
    assert_equal ["634396b2f541a9f2d58b00be1a07f0c358b999b3"], c.parents.map { |p| p.id }
    assert_equal "672eca9b7f9e09c22dcb128c283e8c3c8d7697a4", c.tree.id
    assert_equal "Tom Preston-Werner <tom@mojombo.com>", c.author
    assert_equal Time.at(1191999972), c.authored_date
    assert_equal "Tom Preston-Werner <tom@mojombo.com>", c.committer
    assert_equal Time.at(1191999972), c.committed_date
    assert_equal "implement Grit#heads", c.message
    
    c = commits[1]
    assert_equal [], c.parents
    
    c = commits[2]
    assert_equal ["6e64c55896aabb9a7d8e9f8f296f426d21a78c2c", "7f874954efb9ba35210445be456c74e037ba6af2"], c.parents.map { |p| p.id }
    assert_equal "Merge branch 'site'", c.message
  end
  
  # commit
  
  def test_commit
    commit = @r.commit('634396b2f541a9f2d58b00be1a07f0c358b999b3')
    
    assert_equal "634396b2f541a9f2d58b00be1a07f0c358b999b3", commit.id
  end
  
  # tree
  
  def test_tree
    Git.any_instance.expects(:ls_tree).returns(fixture('ls_tree_a'))
    tree = @r.tree('master')
    
    assert_equal 4, tree.contents.select { |c| c.instance_of?(Blob) }.size
    assert_equal 3, tree.contents.select { |c| c.instance_of?(Tree) }.size
  end
  
  # blob
  
  def test_blob
    Git.any_instance.expects(:cat_file).returns(fixture('cat_file_blob'))
    blob = @r.blob("abc")
    assert_equal "Hello world", blob.data
  end
  
  # init_bar
  
  def test_init_bare
    Git.any_instance.expects(:init).returns(true)
    Repo.expects(:new).with("/foo/bar.git")
    Repo.init_bare("/foo/bar.git")
  end
  
  # inspect
  
  def test_inspect
    assert_equal %Q{#<Grit::Repo "#{GRIT_REPO}/.git">}, @r.inspect
  end
end