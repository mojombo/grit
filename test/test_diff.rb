require File.dirname(__FILE__) + '/helper'

class TestDiff < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end

  # list_from_string

  def test_list_from_string_new_mode
    output = fixture('diff_new_mode')

    diffs = Grit::Diff.list_from_string(@r, output)
    assert_equal 2, diffs.size
    assert_equal 10, diffs.first.diff.split("\n").size
    assert_equal nil, diffs.last.diff
  end
end
