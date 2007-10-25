require File.dirname(__FILE__) + '/helper'

class TestCommit < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end
  
  # __bake__
  
  def test_bake
    Git.any_instance.expects(:rev_list).returns(fixture('rev_list_single'))
    @c = Commit.create(@r, :id => '4c8124ffcf4039d292442eeccabdeca5af5c5017')
    @c.author # bake
    
    assert_equal "Tom Preston-Werner", @c.author.name
    assert_equal "tom@mojombo.com", @c.author.email
  end
  
  # to_s
  
  def test_to_s
    @c = Commit.create(@r, :id => 'abc')
    assert_equal "abc", @c.to_s
  end
  
  # inspect
  
  def test_inspect
    @c = Commit.create(@r, :id => 'abc')
    assert_equal %Q{#<Grit::Commit "abc">}, @c.inspect
  end
end