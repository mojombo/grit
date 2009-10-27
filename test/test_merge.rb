require File.dirname(__FILE__) + '/helper'
require 'pp'

class TestMerge < Test::Unit::TestCase

  def setup
    @r = Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
    @merge = fixture('merge_result')
  end

  def test_from_string
    m = Grit::Merge.new(@merge)
    assert_equal m.sections, 3
    assert_equal m.conflicts, 1
  end

end