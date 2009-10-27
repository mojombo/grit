require File.dirname(__FILE__) + '/helper'

class TestCommitWrite < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end

  def test_commit
    Git.any_instance.expects(:commit).returns(fixture('commit'))
    results = @r.commit_index('my message')
    assert_match /Created commit/, results
  end

  def test_commit_all
    Git.any_instance.expects(:commit).returns(fixture('commit'))
    results = @r.commit_all('my message')
    assert_match /Created commit/, results
  end

end
