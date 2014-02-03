require File.dirname(__FILE__) + '/helper'

class TestRemote < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end

  # inspect

  def test_inspect
    remote = @r.remotes.first
    assert_equal %Q{#<Grit::Remote "#{remote.name}">}, remote.inspect
  end

  def test_remote
    remote = @r.remote('origin/HEAD')
    assert_equal remote.name, 'origin/HEAD'
  end

end
