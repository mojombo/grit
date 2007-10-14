require File.dirname(__FILE__) + '/helper'

class TestHead < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end
  
  # inspect
  
  def test_inspect
    Git.any_instance.expects(:for_each_ref).returns(fixture('for_each_ref'))
    
    head = @r.heads.first
    
    assert_equal %Q{#<Grit::Head "#{head.name}">}, head.inspect
  end
end