require File.dirname(__FILE__) + '/helper'

class TestPatch < Test::Unit::TestCase
  def setup
    @path = cloned_testpath('revert.git')
    @r = Repo.new(@path)
    @master = '7c45b5f16ff3bae2a0063191ef832701214d4df5'
    @cherry = '73bd3b5e44af956b2e0d64d7a2ee5931396c31e3'
  end

  def teardown
    FileUtils.rm_rf @path
  end

  def test_get_patch
    patch = @r.git.get_patch(@cherry)
    assert_match /\+INITIAL\!/, patch
  end

  def test_check_applies
    assert_equal 0, @r.git.check_applies(@master, @cherry)
  end

  def test_apply_patch
    patch    = @r.git.get_patch(@cherry)
    tree_sha = @r.git.apply_patch(@master, patch)
    tree     = Grit::Tree.create(@r, :id => tree_sha)
    blob     = tree / 'B.md'
    assert_match /^INITIAL\!/, blob.data
  end
end