require File.dirname(__FILE__) + '/helper'
require 'pp'

class TestBlame < Test::Unit::TestCase

  def setup
    @r = Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
  end

  def test_simple_blame
    commit = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    blame = @r.blame('History.txt', commit)
    assert_equal 5, blame.lines.size
    line = blame.lines[2]
    assert_equal '* 1 major enhancement', line.line
    assert_equal 3, line.lineno
    assert_equal 3, line.oldlineno
    assert_equal '634396b2f541a9f2d58b00be1a07f0c358b999b3', line.commit.id
  end

  def test_depth_blame
    commit = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    blame = @r.blame('lib/grit.rb', commit)
    assert_equal 37, blame.lines.size
    line = blame.lines[24]
    assert_equal "require 'grit/diff'", line.line
    assert_equal 25, line.lineno
    assert_equal 16, line.oldlineno
    assert_equal '46291865ba0f6e0c9818b11be799fe2db6964d56', line.commit.id
  end

  def test_line_range_blame
    commit = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    blame = @r.blame('lib/grit.rb', commit, 25, 26)
    assert_equal 2, blame.lines.size
    line = blame.lines[0]
    assert_equal "require 'grit/diff'", line.line
    assert_equal 25, line.lineno
    assert_equal 16, line.oldlineno
    assert_equal '46291865ba0f6e0c9818b11be799fe2db6964d56', line.commit.id
    line = blame.lines[1]
    assert_equal "require 'grit/config'", line.line
    assert_equal 26, line.lineno
    assert_equal 23, line.oldlineno
    assert_equal 'f1964ad1919180dd1d9eae9d21a1a1f68ac60e77', line.commit.id
  end

  def test_single_line_blame
    commit = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    blame = @r.blame('lib/grit.rb', commit, 25)
    assert_equal 1, blame.lines.size
    line = blame.lines[0]
    assert_equal "require 'grit/diff'", line.line
    assert_equal 25, line.lineno
    assert_equal 16, line.oldlineno
    assert_equal '46291865ba0f6e0c9818b11be799fe2db6964d56', line.commit.id
  end
end
