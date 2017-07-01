require File.dirname(__FILE__) + '/helper'
require 'tempfile'

class TestGritSpaces < Test::Unit::TestCase

  def setup
    @repo = Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git_spaces]), :is_bare => true)
  end

  def test_log_with_path_no_leading_space
    log = @repo.log('master', 'a file')
    assert_equal 1, log.size
    assert_equal "7f09709727b53fdf3c6c6a6ae653515c4e1a3ef2", log.first.to_s
  end

  def test_log_with_path_leading_space
    log = @repo.log('master', ' an evil file with a leading space')
    assert_equal 1, log.size
    assert_equal "2edb031f77340b65a897e8536ad75f7b7596a607", log.first.to_s
  end

  def test_log_with_path_trailing_space
    log = @repo.log('master', 'an evil file with a trailing space ')
    assert_equal 1, log.size
    assert_equal "2edb031f77340b65a897e8536ad75f7b7596a607", log.first.to_s
  end


  def test_log_with_path_no_leading_space_in_a_branch
    log = @repo.log('branch_one', 'simple_file')
    assert_equal 1, log.size
    assert_equal "8f4094b31327dd0223979adc288e2b12ca86b0a1", log.first.to_s
  end

  def test_log_with_path_leading_space_in_a_branch
    log = @repo.log('branch_one', ' a leading space file in a branch')
    assert_equal 1, log.size
    assert_equal "36a4f6bc8c5e4e67534b98c996f4e91ffff73ea5", log.first.to_s
  end

  def test_tree_with_leading_space
    tree = @repo.tree()
    names = tree.blobs.collect { |b| b.name }
    assert names.include?(" an evil file with a leading space"), "does not contain the leading space named file"
  end

  def test_tree_with_trailing_space
    tree = @repo.tree()
    names = tree.blobs.collect { |b| b.name }
    assert names.include?("an evil file with a trailing space "), "does not contain the trailing space named file"
  end
end
