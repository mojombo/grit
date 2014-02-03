require File.dirname(__FILE__) + '/helper'

class TestDiff < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end

  # list_from_string

  def test_list_from_string_new_mode
    output = fixture('diff_new_mode')

    diffs = Grit::Diff.list_from_string(@r, output)
    assert_equal 2,   diffs.size
    assert_equal 10,  diffs.first.diff.split("\n").size
    assert_equal '',  diffs.last.diff
  end

  def test_list_from_string_with_renames
    output = fixture('diff_renames')

    diffs = Grit::Diff.list_from_string(@r, output)

    # rename + update
    #assert_equal 5,             diffs.size
    assert_equal 'LICENSE',     diffs[0].a_path
    assert_equal 'MIT-LICENSE', diffs[0].b_path
    assert_equal 90,            diffs[0].similarity_index
    assert                      diffs[0].renamed_file
    assert_equal 2,             diffs[0].hunks.length
    assert_equal [1, 6, 1, 6],  [diffs[0].hunks[0].a_first_line, diffs[0].hunks[0].a_lines, diffs[0].hunks[0].b_first_line, diffs[0].hunks[0].b_lines]
    assert_equal [19, 4, 19, 4], [diffs[0].hunks[1].a_first_line, diffs[0].hunks[1].a_lines, diffs[0].hunks[1].b_first_line, diffs[0].hunks[1].b_lines]

    # updated file
    assert_equal 'README.md', diffs[1].a_path
    assert_equal 'README.md', diffs[1].b_path
    assert                   !diffs[1].renamed_file
    assert                   !diffs[1].new_file
    assert                   !diffs[1].deleted_file
    assert_equal 1,          diffs[1].hunks.length
    assert_equal [1, 4, 1, 4], [diffs[1].hunks[0].a_first_line, diffs[1].hunks[0].a_lines, diffs[1].hunks[0].b_first_line, diffs[1].hunks[0].b_lines]

    # deleted file
    assert_equal 'Rakefile', diffs[2].a_path
    assert_equal 'Rakefile', diffs[2].b_path
    assert                   diffs[2].deleted_file
    assert_equal 1,          diffs[2].hunks.length
    assert_equal [1, 149, 0, 0], [diffs[2].hunks[0].a_first_line, diffs[2].hunks[0].a_lines, diffs[2].hunks[0].b_first_line, diffs[2].hunks[0].b_lines]

    # rename w/o update
    assert_equal 'PURE_TODO', diffs[3].a_path
    assert_equal 'TODO',      diffs[3].b_path
    assert_equal 100,         diffs[3].similarity_index
    assert                    diffs[3].renamed_file
    assert_equal 0,           diffs[3].hunks.length
    assert diffs[3].diff.size.zero?

    # created file
    assert_equal 'foobar', diffs[4].a_path
    assert_equal 'foobar', diffs[4].b_path
    assert                 diffs[4].new_file
    assert_equal 1,        diffs[4].hunks.length
    assert_equal [0, 0, 1, nil], [diffs[4].hunks[0].a_first_line, diffs[4].hunks[0].a_lines, diffs[4].hunks[0].b_first_line, diffs[4].hunks[0].b_lines]
  end
end
