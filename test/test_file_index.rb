require File.dirname(__FILE__) + '/helper'
require 'pp'

class TestFileIndex < Test::Unit::TestCase
  
  def setup
    @index = Grit::GitRuby::FileIndex.new(File.join(File.dirname(__FILE__), *%w[dot_git]))
    @commit = 'c12f398c2f3c4068ca5e01d736b1c9ae994b2138'
  end

  def test_count_all 
    assert_equal 107, @index.count_all
  end

  def test_count
    assert_equal 20, @index.count(@commit)
  end

  def test_files
    files = @index.files(@commit)
    assert_equal 4, files.size
    assert_equal "lib/grit/blob.rb", files.first
  end

  def test_commits_for
    commits = @index.commits_for('lib/grit/blob.rb')
    assert commits.include?('3e0955045cb189a7112015c26132152a94f637bf')
    assert_equal 8, commits.size
  end

  def test_last_commits_array
    arr = @index.last_commits(@commit, ['lib/grit/git.rb', 'lib/grit/actor.rb', 'lib/grit/commit.rb'])
    assert_equal '74fd66519e983a0f29e16a342a6059dbffe36020', arr['lib/grit/git.rb']
    assert_equal @commit, arr['lib/grit/commit.rb']
    assert_equal nil, arr['lib/grit/actor.rb']
  end
  
  def test_last_commits_pattern
    arr = @index.last_commits(@commit, /lib\/grit\/[^\/]*$/)
    assert_equal 10, arr.size
    assert_equal @commit, arr['lib/grit/commit.rb']
    assert_equal nil, arr['lib/grit/actor.rb']
  end
  
  def test_last_commits_array
    arr = @index.last_commits(@commit, ['lib/grit.rb', 'lib/grit/'])
    assert_equal @commit, arr['lib/grit/']
  end
  
end