require File.dirname(__FILE__) + '/helper'
require 'pp'

class TestRubyGitAlt < Test::Unit::TestCase

  def setup
    @git1 = Grit::Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
    @git2 = Grit::Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git_clone]), :is_bare => true)
    @git3 = Grit::Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git_clone2]), :is_bare => true)
    @commit_sha = 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a'
    @tree_sha = 'cd7422af5a2e0fff3e94d6fb1a8fff03b2841881'
    @blob_sha = '4232d073306f01cf0b895864e5a5cfad7dd76fce'
  end

  def test_basic
    sha_hex = [@commit_sha].pack("H*")
    assert @git1.git.ruby_git.in_loose?(sha_hex)
    assert @git2.git.ruby_git.in_loose?(sha_hex)
    assert @git1.git.ruby_git.object_exists?(@commit_sha)
    assert @git2.git.ruby_git.object_exists?(@commit_sha)
    assert_equal 10, @git1.commits.size
    assert_equal 10, @git2.commits.size
  end

  def test_clone_of_clone
    sha_hex = [@commit_sha].pack("H*")
    assert @git2.git.ruby_git.in_loose?(sha_hex)
    assert @git3.git.ruby_git.in_loose?(sha_hex)
    assert @git2.git.ruby_git.object_exists?(@commit_sha)
    assert @git3.git.ruby_git.object_exists?(@commit_sha)
    assert_equal 10, @git2.commits.size
    assert_equal 10, @git3.commits.size
  end

  def test_tree_path
    file = @git2.tree('master', ['test/test_head.rb']).contents.first.name
    assert_equal file, 'test/test_head.rb'
  end

end