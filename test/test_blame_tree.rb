require File.dirname(__FILE__) + '/helper'
require 'pp'

class TestBlameTree < Test::Unit::TestCase
  
  def setup
    @git = Git.new(File.join(File.dirname(__FILE__), *%w[dot_git]))
  end

  def test_blame_tree    
    commit = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    tree = @git.blame_tree(commit)
    last_commit_sha = tree['History.txt']
    assert_equal last_commit_sha, '7bcc0ee821cdd133d8a53e8e7173a334fef448aa'
  end

  def test_blame_tree_path   
    commit = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    tree = @git.blame_tree(commit, 'lib')
    last_commit_sha = tree['grit.rb']
    assert_equal last_commit_sha, '5a0943123f6872e75a9b1dd0b6519dd42a186fda'
  end

  def test_blame_tree_multi_path
    commit = '2d3acf90f35989df8f262dc50beadc4ee3ae1560'
    tree = @git.blame_tree(commit, 'lib/grit')
    last_commit_sha = tree['diff.rb']
    assert_equal last_commit_sha, '28e7a1d3dd172a8e757ff777ab205a538b80385e'
  end
  
end