require File.dirname(__FILE__) + '/helper'

class TestHead < Test::Unit::TestCase
  def setup
    @r = Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
  end
  
  # inspect
  
  def test_inspect
    head = @r.heads.first
    assert_equal %Q{#<Grit::Head "master">}, head.inspect
  end
  
  # heads with slashes

  def test_heads_with_slashes
    head = @r.heads[1]
    assert_equal %Q{#<Grit::Head "test/chacon">}, head.inspect
  end
end
