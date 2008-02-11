require File.dirname(__FILE__) + '/helper'

class TestDiff < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end
  
  # list_from_string
  
  def test_list_from_string_new_mode
    output = fixture('diff_new_mode')
    
    diffs = Diff.list_from_string(@r, output)
    assert_equal 1, diffs.size
    assert_equal 10, diffs.first.diff.split("\n").size
  end
end
