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
    Git.expects(:for_each_ref).returns("634396b2f541a9f2d58b00be1a07f0c358b999b3 refs/heads/master \
    initial grit setup\0Tom Preston-Werner <tom@mojombo.com> 1191997100 -0700")
    
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
end