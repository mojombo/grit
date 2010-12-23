require File.dirname(__FILE__) + '/helper'

class TestProcess < Test::Unit::TestCase
  def test_argv_array_execs
    p = Grit::Process.new(['printf', '%s %s %s', '1', '2', '3 4'])
    assert p.success?
    assert_equal "1 2 3 4", p.out
  end

  def test_argv_string_uses_sh
    p = Grit::Process.new("echo via /bin/sh")
    assert p.success?
    assert_equal "via /bin/sh\n", p.out
  end

  def test_stdout
    p = Grit::Process.new(['echo', 'boom'])
    assert_equal "boom\n", p.out
    assert_equal "", p.err
  end

  def test_stderr
    p = Grit::Process.new('echo boom 1>&2')
    assert_equal "", p.out
    assert_equal "boom\n", p.err
  end

  def test_status
    p = Grit::Process.new('exit 3')
    assert !p.status.success?
    assert_equal 3, p.status.exitstatus
  end

  def test_env
    p = Grit::Process.new('echo $FOO', { 'FOO' => 'BOOYAH' })
    assert_equal "BOOYAH\n", p.out
  end

  def test_chdir
    p = Grit::Process.new(["pwd"], {}, :chdir => File.dirname(Dir.pwd))
    assert_equal File.dirname(Dir.pwd) + "\n", p.out
  end

  def test_input
    input = "HEY NOW\n" * 100_000 # 800K
    p = Grit::Process.new(['wc', '-l'], {}, :input => input)
    assert_equal 100_000, p.out.strip.to_i
  end

  def test_max
    fail if jruby?
    assert_raise Grit::Process::MaximumOutputExceeded do
      Grit::Process.new(['yes'], {}, :max => 100_000)
    end
  end

  def test_max_with_child_hierarchy
    fail if jruby?
    assert_raise Grit::Process::MaximumOutputExceeded do
      Grit::Process.new(['/bin/sh', '-c', 'yes'], {}, :max => 100_000)
    end
  end

  def test_max_with_stubborn_child
    fail if jruby?
    assert_raise Grit::Process::MaximumOutputExceeded do
      Grit::Process.new("trap '' TERM; yes", {}, :max => 100_000)
    end
  end

  def test_timeout
    assert_raise Grit::Process::TimeoutExceeded do
      Grit::Process.new(['sleep 1'], {}, :timeout => 0.05)
    end
  end

  def test_timeout_with_child_hierarchy
    fail if jruby?
    assert_raise Grit::Process::TimeoutExceeded do
      Grit::Process.new(['/bin/sh', '-c', 'yes'], {}, :timeout => 0.05)
    end
  end

  def test_lots_of_input_and_lots_of_output_at_the_same_time
    input = "stuff on stdin \n" * 1_000
    command = "
      while read line
      do
        echo stuff on stdout;
        echo stuff on stderr 1>&2;
      done
    "
    p = Grit::Process.new(['/bin/sh', '-c', command], {}, :input => input)
    assert_equal input.size, p.out.size
    assert_equal input.size, p.err.size
    assert p.success?
  end

  def test_input_cannot_be_written_due_to_broken_pipe
    input = "1" * 100_000
    p = Grit::Process.new(['false'], {}, :input => input)
    assert !p.success?
  end
end
