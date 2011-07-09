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
    Grit.expects(:log).with(includes("git: 'bad' is not a git command"))
    @git.bad
  end

  def test_logs_stderr_when_skipping_timeout
    Grit.debug = true
    Grit.stubs(:log)
    Grit.expects(:log).with(includes("git: 'bad' is not a git command"))
    @git.bad :timeout => false
  end

  def test_transform_options
    assert_equal ["-s"], @git.transform_options({:s => true})
    assert_equal [], @git.transform_options({:s => false})
    assert_equal ["-s '5'"], @git.transform_options({:s => 5})

    assert_equal ["--max-count"], @git.transform_options({:max_count => true})
    assert_equal ["--max-count='5'"], @git.transform_options({:max_count => 5})

    assert_equal ["-s", "-t"], @git.transform_options({:s => true, :t => true}).sort
  end

  def test_uses_native_command_execution
    @git.expects(:native)
    @git.something
  end

  def test_can_skip_timeout
    Timeout.expects(:timeout).never
    @git.something(:timeout => false)
  end

  def test_raises_if_too_many_bytes
    fail if jruby?
    assert_raises Grit::Git::GitTimeout do
      @git.sh "yes | head -#{Grit::Git.git_max_size + 1}"
    end
  end

  def test_raises_on_slow_shell
    Grit::Git.git_timeout = 0.0000001
    assert_raises Grit::Git::GitTimeout do
      @git.version
    end
  ensure
    Grit::Git.git_timeout = 5.0
  end

  def test_with_timeout_default_parameter
    assert_nothing_raised do
      Git::Git.with_timeout do
        @git.version
      end
    end
  end

  def test_it_really_shell_escapes_arguments_to_the_git_shell
    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' foo --bar='bazz\\'er'")
    @git.run('', :foo, '', {:bar => "bazz'er"}, [])
    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' bar -x 'quu\\'x'")
    @git.run('', :bar, '', {:x => "quu'x"}, [])
  end

  def test_it_shell_escapes_the_standalone_argument
    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' foo 'bar\\'s'")
    @git.run('', :foo, '', {}, ["bar's"])

    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' foo 'bar' '\\; echo \\'noooo\\''")
    @git.run('', :foo, '', {}, ["bar", "; echo 'noooo'"])
  end

  def test_piping_should_work_on_1_9
    @git.expects(:sh).with("#{Git.git_binary} --git-dir='#{@git.git_dir}' archive 'master' | gzip")
    @git.archive({}, "master", "| gzip")
  end

  def test_fs_read
    f = stub
    File.expects(:read).with(File.join(@git.git_dir, 'foo')).returns('bar')
    assert_equal 'bar', @git.fs_read('foo')
  end

  def test_fs_write
    f = stub
    f.expects(:write).with('baz')
    FileUtils.expects(:mkdir_p).with(File.join(@git.git_dir, 'foo'))
    File.expects(:open).with(File.join(@git.git_dir, 'foo/bar'), 'w').yields(f)
    @git.fs_write('foo/bar', 'baz')
  end

  def test_fs_delete
    FileUtils.expects(:rm_rf).with(File.join(@git.git_dir, 'foo'))
    @git.fs_delete('foo')
  end

  def test_passing_env_to_native
    args = [
      { 'A' => 'B' },
      Grit::Git.git_binary, "--git-dir=#{@git.git_dir}", "help", "-a",
      {:input => nil, :chdir => nil, :timeout => Grit::Git.git_timeout, :max => Grit::Git.git_max_size}
    ]
    p = Grit::Git::Child.new(*args)
    Grit::Git::Child.expects(:new).with(*args).returns(p)
    @git.native(:help, {:a => true, :env => { 'A' => 'B' }})
  end

  def test_native_process_info_option_on_failure
    exitstatus, out, err = @git.no_such_command({:process_info => true})
    assert_equal 1, exitstatus
    assert !err.empty?
  end

  def test_native_process_info_option_on_success
    exitstatus, out, err = @git.help({:process_info => true})
    assert_equal 0, exitstatus
    assert !out.empty?
    assert err.empty?
  end

  def test_raising_exceptions_when_native_git_commands_fail
    assert_raise Grit::Git::CommandFailed do
      @git.native(:bad, {:raise => true})
    end
  end
end
