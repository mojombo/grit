require File.dirname(__FILE__) + '/helper'

class TestGitPatching < Test::Unit::TestCase
  def setup
    @testdir  = File.dirname(__FILE__)
    @patchdir = File.join(@testdir, 'patch')
    @clonedir = File.join(@testdir, 'patch_clone.git')
    @git = Git.new(@patchdir)
  end

  def teardown
    Grit.debug = false
    FileUtils.rm_rf(@clonedir)
  end

  def test_gets_a_valid_patch
    assert_match /\-patchme/, @git.get_patch("good")
    assert_match /\-initial/, @git.get_patch("bad")
  end

  def test_checks_patch_applies
    assert_equal 0, @git.check_applies("master", "good")
    assert_equal 1, @git.check_applies("master", "bad")
  end

  def test_applies_patch
    repo  = Grit::Repo.new(@patchdir, :is_bare => true)
    clone = repo.fork_bare(@clonedir)
    assert_equal 'patchme', (clone.tree / 'patchme').data.strip

    badpatch = clone.git.get_patch('bad')
    assert !clone.git.apply_patch('master', badpatch)
    assert_equal 'patchme', (clone.tree / 'patchme').data.strip

    goodpatch = clone.git.get_patch('good')
    sha = clone.git.apply_patch('master', goodpatch)
    assert_equal 'patched', (clone.tree(sha) / 'patchme').data.strip
  end
end