require File.dirname(__FILE__) + '/helper'

class TestGrit < Test::Unit::TestCase
  def setup
    @g = Grit.new(GRIT_REPO)
  end
  
  def test_description
    assert_equal "Grit is a ruby library for interfacing with git repositories.", @g.description
  end
end