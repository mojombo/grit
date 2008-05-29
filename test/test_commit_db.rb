require File.dirname(__FILE__) + '/helper'
require 'tempfile'

class TestCommitDb < Test::Unit::TestCase
  
  def setup    
    git_dir = File.join(File.dirname(__FILE__), *%w[dot_git])
    
    tf= Tempfile.new('tempindex')
    puts index = tf.path
    tf.close
    File.unlink(index)
    Dir.mkdir(index)
    
    @git = Git.new(git_dir)
    @commit_db = CommitDb.new(@git, index)

    @commit_sha = '5e3ee1198672257164ce3fe31dea3e40848e68d5'
    @tree_sha = 'cd7422af5a2e0fff3e94d6fb1a8fff03b2841881'
    @blob_sha = '4232d073306f01cf0b895864e5a5cfad7dd76fce'
  end

  def test_update_db_new
    @commit_db.update_db
  end

  def test_update_db_one_commit
  end

  def test_update_db_new_branch
  end

  def test_log
  end
  
  def test_rev_list
  end

  def test_rev_list_max_count
  end

  def test_rev_list_since
  end

  def test_rev_list_until
  end

  def test_rev_list_range
  end

  def test_rev_list_skip
  end

  
end