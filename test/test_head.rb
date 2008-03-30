require File.dirname(__FILE__) + '/helper'

class TestHead < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
    Git.any_instance.expects(:for_each_ref).returns(fixture('for_each_ref'))
  end
  
  # inspect
  
  def test_inspect
    head = @r.heads.first
    assert_equal %Q{#<Grit::Head "#{head.name}">}, head.inspect
  end

  # heads with slashes

  def test_heads_with_slashes
    head = @r.heads.last
    assert_equal %Q{#<Grit::Head "mojombo/master">}, head.inspect
  end
end
