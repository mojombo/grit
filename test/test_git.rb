require File.dirname(__FILE__) + '/helper'

class TestGit < Test::Unit::TestCase
  def setup
    @git = Git.new(File.join(File.dirname(__FILE__), *%w[..]))
  end
  
  def teardown
    Grit.debug = false
  end

  def test_method_missing
    assert_match(/^git version [\w\.]*$/, @git.version)
  end
  
  def test_logs_stderr
    Grit.debug = true
    Grit.stubs(:log)
    Grit.expects(:log).with(includes("git: 'bad' is not a git-command"))
    @git.bad
  end
  
  def testl_logs_stderr_when_skipping_timeout 
    Grit.debug = true
    Grit.stubs(:log)
    Grit.expects(:log).with(includes("git: 'bad' is not a git-command"))
    @git.bad :timeout => false
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
      @git.version
    end
  end

  def test_raises_on_slow_shell
    Grit::Git.git_timeout = 0.0000001
    assert_raises Grit::Git::GitTimeout do
      @git.version
    end
    Grit::Git.git_timeout = 5.0
  end
  
  def test_it_really_shell_escapes_arguments_to_the_git_shell
    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' foo --bar='bazz\\'er'")
    @git.foo(:bar => "bazz'er")
    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' bar -x 'quu\\'x'")
    @git.bar(:x => "quu'x")
  end
  
  def test_it_shell_escapes_the_standalone_argument
    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' foo 'bar\\'s'")
    @git.foo({}, "bar's")
    
    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' foo 'bar' '\\; echo \\'noooo\\''")
    @git.foo({}, "bar", "; echo 'noooo'")
  end
  
  def test_piping_should_work_on_1_9
    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' archive 'master' | gzip")
    @git.archive({}, "master", "| gzip")
  end
end
