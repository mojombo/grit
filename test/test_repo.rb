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
    
    assert_equal '634396b2f541a9f2d58b00be1a07f0c358b999b3', head.id
    assert_equal 'refs/heads/master', head.name
    assert_equal 'initial grit setup', head.message
    assert_equal 'Tom Preston-Werner <tom@mojombo.com>', head.committer
    assert_equal Time.at(1191997100), head.date
  end
  
  # branches
  
  def test_branches
    branches = @g.branches
    
    assert_equal ['master'], branches
  end
  
  # commits
  
  def test_commits
    Git.any_instance.expects(:rev_list).returns(fixture('rev_list'))
    
    commits = @g.commits('master', 10)
    
    c = commits.first
    assert_equal '4c8124ffcf4039d292442eeccabdeca5af5c5017', c.id
    assert_equal ["634396b2f541a9f2d58b00be1a07f0c358b999b3"], c.parents
    assert_equal "672eca9b7f9e09c22dcb128c283e8c3c8d7697a4", c.tree
    assert_equal "Tom Preston-Werner <tom@mojombo.com>", c.author
    assert_equal Time.at(1191999972), c.authored_date
    assert_equal "Tom Preston-Werner <tom@mojombo.com>", c.committer
    assert_equal Time.at(1191999972), c.committed_date
    assert_equal "implement Grit#heads", c.message
  end
end