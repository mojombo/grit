require File.dirname(__FILE__) + '/helper'

class TestRemote < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
    Git.any_instance.expects(:for_each_ref).returns(fixture('for_each_ref_remotes'))
  end

  # inspect

  def test_inspect
    remote = @r.remotes.first
    assert_equal %Q{#<Grit::Remote "#{remote.name}">}, remote.inspect
  end
end
