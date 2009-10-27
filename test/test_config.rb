require File.dirname(__FILE__) + '/helper'

class TestConfig < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end

  # data

  def test_bracketed_fetch
    Git.any_instance.expects(:config).returns(fixture('simple_config'))

    config = @r.config

    assert_equal "git://github.com/mojombo/grit.git", config["remote.origin.url"]
  end

  def test_bracketed_fetch_returns_nil
    Git.any_instance.expects(:config).returns(fixture('simple_config'))

    config = @r.config

    assert_equal nil, config["unknown"]
  end

  def test_fetch
    Git.any_instance.expects(:config).returns(fixture('simple_config'))

    config = @r.config

    assert_equal "false", config.fetch("core.bare")
  end

  def test_fetch_with_default
    Git.any_instance.expects(:config).returns(fixture('simple_config'))

    config = @r.config

    assert_equal "default", config.fetch("unknown", "default")
  end

  def test_fetch_without_default_raises
    Git.any_instance.expects(:config).returns(fixture('simple_config'))

    config = @r.config

    assert_raise(IndexError) do
      config.fetch("unknown")
    end
  end

  def test_set_value
    Git.any_instance.expects(:config).with({}, 'unknown', 'default')

    config = @r.config
    config["unknown"] = "default"
  end
end
