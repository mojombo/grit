require File.dirname(__FILE__) + '/helper'

class TestTag < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end
  
  # list_from_string
  
  def test_list_from_string
    tags = @r.tags
    
    assert_equal 1, tags.size
    assert_equal 'v0.7.0', tags.first.name
    assert_equal 'f0055fda16c18fd8b27986dbf038c735b82198d7', tags.first.commit.id
  end
  
  # inspect
  
  def test_inspect
    tag = @r.tags.first
    
    assert_equal %Q{#<Grit::Tag "#{tag.name}">}, tag.inspect
  end
end