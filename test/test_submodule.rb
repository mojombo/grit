require File.dirname(__FILE__) + '/helper'

class TestSubmodule < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
    @s = Submodule.allocate
  end

  # config

  def test_config
    data = fixture('gitmodules')
    blob = stub(:data => data, :id => 'abc')
    tree = stub(:'/' => blob)
    commit = stub(:tree => tree)
    repo = stub(:commit => commit)

    config = Submodule.config(repo)

    assert_equal "git://github.com/mojombo/glowstick", config['test/glowstick']['url']
    assert_equal "git://github.com/mojombo/god", config['god']['url']
  end

  def test_config_with_windows_lineendings
    data = fixture('gitmodules').gsub(/\n/, "\r\n")
    blob = stub(:data => data, :id => 'abc')
    tree = stub(:'/' => blob)
    commit = stub(:tree => tree)
    repo = stub(:commit => commit)

    config = Submodule.config(repo)

    assert_equal "git://github.com/mojombo/glowstick", config['test/glowstick']['url']
    assert_equal "git://github.com/mojombo/god", config['god']['url']
  end

  def test_no_config
    tree = stub(:'/' => nil)
    commit = stub(:tree => tree)
    repo = stub(:commit => commit)

    config = Submodule.config(repo)

    assert_equal({}, config)
  end

  def test_empty_config
    blob = stub(:data => '', :id => 'abc')
    tree = stub(:'/' => blob)
    commit = stub(:tree => tree)
    repo = stub(:commit => commit)

    config = Submodule.config(repo)

    assert_equal({}, config)
  end

  # inspect

  def test_inspect
    @t = Submodule.create(@r, :id => 'abc')
    assert_equal %Q{#<Grit::Submodule "abc">}, @t.inspect
  end

  def test_basename
    @submodule = Submodule.create(@r, :name => 'foo/bar')
    assert_equal "bar", @submodule.basename
  end
end