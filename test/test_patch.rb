require File.dirname(__FILE__) + '/helper'

class TestPatch < Test::Unit::TestCase
  def setup
    @path = cloned_testpath('revert.git')
    @r = Repo.new(@path)
    @master   = '7c45b5f16ff3bae2a0063191ef832701214d4df5'
    @cherry   = '73bd3b5e44af956b2e0d64d7a2ee5931396c31e3'
    @spam_a_1 = '302a5491a9a5ba12c7652ac831a44961afa312d2'
    @spam_a_2 = 'b26b791cb7917c4f37dd9cb4d1e0efb24ac4d26f'
    @spam_b   = @master
  end

  def teardown
    FileUtils.rm_rf @path
  end

  def test_get_patch
    patch = @r.git.get_patch(@cherry)
    assert_match /\+INITIAL\!/, patch
  end

  def test_get_reverse_patch
    patch = @r.git.get_patch(@cherry, :R => true)
    assert_match /\-INITIAL\!/, patch
  end

  def test_check_applies
    assert_equal 0, @r.git.check_applies(@master, @cherry)
    assert_equal 1, @r.git.check_applies(@master, @spam_a_1)
  end

  def test_check_patch_applies
    revert_master = @r.git.get_patch(@master,   :R => true)
    revert_spam_a = @r.git.get_patch(@spam_a_1, :R => true)
    revert_spams  = @r.git.get_patch("#{@spam_a_1}^", @spam_a_2, :R => true)
    assert_equal 0, @r.git.check_patch_applies(@master, revert_master)
    assert_equal 1, @r.git.check_patch_applies(@master, revert_spam_a)
    assert_equal 0, @r.git.check_patch_applies(@master, revert_spams)
  end

  def test_apply_patch
    patch    = @r.git.get_patch(@cherry)
    tree_sha = @r.git.apply_patch(@master, patch)
    tree     = Grit::Tree.create(@r, :id => tree_sha)
    blob     = tree / 'B.md'
    assert_match /^INITIAL\!/, blob.data
  end

  def test_apply_multiple_reverts
    patch    = @r.git.get_patch("#{@spam_a_1}^", @spam_a_2, :R => true)
    tree_sha = @r.git.apply_patch(@master, patch)
    tree     = Grit::Tree.create(@r, :id => tree_sha)
    blob     = tree / 'A.md'
    assert_equal "INITIAL", blob.data.strip
  end
end