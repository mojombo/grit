require File.dirname(__FILE__) + '/helper'

class TestRepo < Test::Unit::TestCase
  def setup
    @g = Repo.new(GRIT_REPO)
  end
  
  # descriptions
  
  def test_description
    assert_equal "Grit is a ruby library for interfacing with git repositories.", @g.description
  end
  
  # heads
  
  def test_heads_should_return_array_of_head_objects
    @g.heads.each do |head|
      assert_equal Grit::Head, head.class
    end
  end
  
  def test_heads_should_populate_head_data
    Git.any_instance.expects(:for_each_ref).returns(fixture('for_each_ref'))
    
    head = @g.heads.first
    
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
    
    commits = @g.commits('master', 10)
    
    c = commits[0]
    assert_equal '4c8124ffcf4039d292442eeccabdeca5af5c5017', c.id
    assert_equal ["634396b2f541a9f2d58b00be1a07f0c358b999b3"], c.parents
    assert_equal "672eca9b7f9e09c22dcb128c283e8c3c8d7697a4", c.tree
    assert_equal "Tom Preston-Werner <tom@mojombo.com>", c.author
    assert_equal Time.at(1191999972), c.authored_date
    assert_equal "Tom Preston-Werner <tom@mojombo.com>", c.committer
    assert_equal Time.at(1191999972), c.committed_date
    assert_equal "implement Grit#heads", c.message
    
    c = commits[1]
    assert_equal [], c.parents
    
    c = commits[2]
    assert_equal ["6e64c55896aabb9a7d8e9f8f296f426d21a78c2c", "7f874954efb9ba35210445be456c74e037ba6af2"], c.parents
    assert_equal "Merge branch 'site'", c.message
  end
  
  # commit
  
  def test_commit
    commit = @g.commit('634396b2f541a9f2d58b00be1a07f0c358b999b3')
    
    assert_equal "634396b2f541a9f2d58b00be1a07f0c358b999b3", commit.id
  end
  
  # tree
  
  def test_tree
    # @g.tree('master', ['bin/', 'test/'])
  end
end