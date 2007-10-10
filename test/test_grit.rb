require File.dirname(__FILE__) + '/helper'

class TestGrit < Test::Unit::TestCase
  def setup
    @g = Grit.new(GRIT_REPO)
  end
  
  def test_description
    assert_equal "Grit is a ruby library for interfacing with git repositories.", @g.description
  end
  
  def test_heads
    @g.expects(:git).returns("634396b2f541a9f2d58b00be1a07f0c358b999b3 refs/heads/master \
    initial grit setup\0Tom Preston-Werner <tom@mojombo.com> 1191997100 -0700")
    
    heads = @g.heads
    head = heads.first
    assert_equal Grit::Head, head.class
    
    assert_equal '634396b2f541a9f2d58b00be1a07f0c358b999b3', head.id
    assert_equal 'refs/heads/master', head.name
    assert_equal 'initial grit setup', head.message
    assert_equal 'Tom Preston-Werner <tom@mojombo.com>', head.committer
    assert_equal Time.at(1191997100), head.date
  end
  
  def test_git
    assert_match /^git version [\d\.]*$/, @g.git('version')
  end
end