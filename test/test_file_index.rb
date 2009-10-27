require File.dirname(__FILE__) + '/helper'

class TestFileIndex < Test::Unit::TestCase

  def setup_a
    @findex = Grit::GitRuby::FileIndex.new(File.join(File.dirname(__FILE__), *%w[dot_git]))
    @commit = 'c12f398c2f3c4068ca5e01d736b1c9ae994b2138'
  end

  def test_count_all
    setup_a
    assert_equal 107, @findex.count_all
  end

  def test_count
    setup_a
    assert_equal 20, @findex.count(@commit)
  end

  def test_files
    setup_a
    files = @findex.files(@commit)
    assert_equal 4, files.size
    assert_equal "lib/grit/blob.rb", files.first
  end

  def test_commits_for
    setup_a
    commits = @findex.commits_for('lib/grit/blob.rb')
    assert commits.include?('3e0955045cb189a7112015c26132152a94f637bf')
    assert_equal 8, commits.size
  end

  def test_last_commits_array
    setup_a
    arr = @findex.last_commits(@commit, ['lib/grit/git.rb', 'lib/grit/actor.rb', 'lib/grit/commit.rb'])
    assert_equal '74fd66519e983a0f29e16a342a6059dbffe36020', arr['lib/grit/git.rb']
    assert_equal @commit, arr['lib/grit/commit.rb']
    assert_equal nil, arr['lib/grit/actor.rb']
  end

  def test_last_commits_pattern
    setup_a
    arr = @findex.last_commits(@commit, /lib\/grit\/[^\/]*$/)
    assert_equal 10, arr.size
    assert_equal @commit, arr['lib/grit/commit.rb']
    assert_equal nil, arr['lib/grit/actor.rb']
  end

  def test_last_commits_array
    setup_a
    arr = @findex.last_commits(@commit, ['lib/grit.rb', 'lib/grit/'])
    assert_equal @commit, arr['lib/grit/']
  end

end