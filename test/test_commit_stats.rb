require File.dirname(__FILE__) + '/helper'

class TestCommitStats < Test::Unit::TestCase

  def setup
    File.expects(:exist?).returns(true)
    @r = Repo.new(GRIT_REPO)

    Git.any_instance.expects(:log).returns(fixture('log'))
    @stats = @r.commit_stats
  end

  def test_commit_stats
    assert_equal 3, @stats.size
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

end
