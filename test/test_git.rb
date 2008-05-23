require File.dirname(__FILE__) + '/helper'

class TestGit < Test::Unit::TestCase
  def setup
    @git = Git.new(File.join(File.dirname(__FILE__), *%w[..]))
  end
  
  def test_method_missing
    assert_match(/^git version [\w\.]*$/, @git.version)
  end
  
  def test_transform_options
    assert_equal ["-s"], @git.transform_options({:s => true})
    assert_equal ["-s '5'"], @git.transform_options({:s => 5})
    
    assert_equal ["--max-count"], @git.transform_options({:max_count => true})
    assert_equal ["--max-count='5'"], @git.transform_options({:max_count => 5})
    
    assert_equal ["-s", "-t"], @git.transform_options({:s => true, :t => true}).sort
  end

  def test_uses_custom_sh_method
    @git.expects(:sh)
    @git.something
  end

  def test_can_skip_timeout
    @git.expects(:wild_sh)
    @git.something(:timeout => false)
  end

  def test_raises_if_too_many_bytes
    @git.instance_variable_set(:@bytes_read, 6000000)
    assert_raises Grit::Git::GitTimeout do
      @git.something
    end
  end

  def test_raises_on_slow_shell
    Grit::Git.git_timeout = 0.5
    Open4.expects(:popen4).yields( nil, nil, mock(:read => proc { sleep 1 }), nil )
    assert_raises Grit::Git::GitTimeout do
      @git.something
    end
  end

  def test_works_fine_if_quick
    output = 'output'
    Open4.expects(:popen4).yields( nil, nil, mock(:read => output), nil )
    assert_equal output, @git.something
  end
end
