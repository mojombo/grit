require File.dirname(__FILE__) + '/helper'

class TestTag < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end
  
  # list_from_string
  
  def test_list_from_string
    Git.any_instance.expects(:for_each_ref).returns(fixture('for_each_ref_tags'))
    
    tags = @r.tags
    
    assert_equal 1, tags.size
    assert_equal 'v0.7.1', tags.first.name
    assert_equal '634396b2f541a9f2d58b00be1a07f0c358b999b3', tags.first.commit.id
  end
  
  # inspect
  
  def test_inspect
    Git.any_instance.expects(:for_each_ref).returns(fixture('for_each_ref'))
    
    tag = @r.tags.first
    
    assert_equal %Q{#<Grit::Tag "#{tag.name}">}, tag.inspect
  end
end