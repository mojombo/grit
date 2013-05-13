require File.dirname(__FILE__) + '/helper'

class TestCommitStats < Test::Unit::TestCase

  def setup
    File.expects(:exist?).returns(true)
    @r = Repo.new(GRIT_REPO)

    Git.any_instance.expects(:log).returns(fixture('log'))
    @stats = @r.commit_stats
  end

  def test_commit_stats
    assert_equal 4, @stats.size
  end

  # to_hash

  def test_to_hash
    expected = {
      "files"=>
        [["examples/ex_add_commit.rb", 13, 0, 13],
         ["examples/ex_index.rb", 1, 1, 2]],
       "total"=>15,
       "additions"=>14,
       "id"=>"a49b96b339c525d7fd455e0ad4f6fe7b550c9543",
       "deletions"=>1
    }

    assert_equal expected, @stats.assoc('a49b96b339c525d7fd455e0ad4f6fe7b550c9543')[1].to_hash
  end

  def test_spaces_in_filename
    expected = [["filename with spaces.txt", 0, 0, 0 ]]
    assert_equal expected, @stats.assoc('c86075f49283416c95866f6013d11a81f5b1f827')[1].to_hash["files"]
  end

end
