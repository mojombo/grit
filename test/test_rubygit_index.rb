require File.dirname(__FILE__) + '/helper'
require 'pp'

class TestRubyGitIndex < Test::Unit::TestCase

  def setup
    @base_repo = create_temp_repo(File.join(File.dirname(__FILE__), *%w[dot_git_iv2]))
    @git = Grit::Repo.new(@base_repo, :is_bare => true)
    @rgit = @git.git.ruby_git
    @user = Actor.from_string("Tom Werner <tom@example.com>")
  end

  def teardown
    FileUtils.rm_r(@base_repo)
  end

  def create_temp_repo(clone_path)
    filename = 'git_test' + Time.now.to_i.to_s + rand(300).to_s.rjust(3, '0')
    tmp_path = File.join("/tmp/", filename)
    FileUtils.mkdir_p(tmp_path)
    FileUtils.cp_r(clone_path, tmp_path)
    File.join(tmp_path, 'dot_git_iv2')
  end

  def test_add_files
    sha = @git.commits.first.tree.id

    i = @git.index
    i.read_tree(sha)
    i.add('atester.rb', 'test stuff')
    i.commit('message', [@git.commits.first], @user, nil, 'master')

    b = @git.commits.first.tree/'atester.rb'
    assert_equal 'f80c3b68482d5e1c8d24c9b8139340f0d0a928d0', b.id
  end

  def test_add_path_file
    sha = @git.commits.first.tree.id

    i = @git.index
    i.read_tree(sha)
    i.add('lib/atester.rb', 'test stuff')
    i.commit('message', [@git.commits.first], @user, nil, 'master')

    b = @git.commits.first.tree/'lib'/'atester.rb'
    assert_equal 'f80c3b68482d5e1c8d24c9b8139340f0d0a928d0', b.id
    b = @git.commits.first.tree/'lib'/'grit.rb'
    assert_equal '77aa887449c28a922a660b2bb749e4127f7664e5', b.id
  end

  def test_ordered_properly
    sha = @git.commits.first.tree.id

    i = @git.index
    i.read_tree(sha)
    i.add('lib.rb', 'test stuff')
    i.commit('message', [@git.commits.first], @user, nil, 'master')

    tr = @git.commits.first.tree.contents
    entries = tr.select { |c| c.name[0, 3] == 'lib' }.map { |c| c.name }
    assert_equal 'lib.rb', entries[0]
    assert_equal 'lib', entries[1]
  end

  def test_modify_file
    sha = @git.commits.first.tree.id

    i = @git.index
    i.read_tree(sha)
    i.add('README.txt', 'test more stuff')
    i.commit('message', [@git.commits.first], @user, nil, 'master')

    b = @git.commits.first.tree/'README.txt'
    assert_equal 'e45d6b418e34951ddaa3e78e4fc4d3d92a46d3d1', b.id
  end
end