require 'grit/process'

module Grit
  # Override the Grit::Process class's popen4 and waitpid methods to work around
  # various quirks in JRuby.
  class Process
    # Use JRuby's built in IO.popen4 but emulate the special spawn env
    # and options arguments as best we can.
    def popen4(*argv)
      env = (argv.shift if argv[0].is_a?(Hash))  || {}
      opt = (argv.pop   if argv[-1].is_a?(Hash)) || {}

      # emulate :chdir option
      if opt[:chdir]
        previous_dir = Dir.pwd
        Dir.chdir(opt[:chdir])
      else
        previous_dir = nil
      end

      # emulate :env option
      if env.size > 0
        previous_env = ENV
        ENV.merge!(env)
      else
        previous_env = nil
      end

      pid, stdin, stdout, stderr = IO.popen4(*argv)
    ensure
      ENV.replace(previous_env) if previous_env
      Dir.chdir(previous_dir)   if previous_dir
    end

    # JRuby always raises ECHILD on pids returned from its IO.popen4 method
    # for some reason. Return a fake Process::Status object.
    FakeStatus = Struct.new(:pid, :exitstatus, :success?, :fake?)
    def waitpid(pid)
      ::Process::waitpid(pid)
      $?
    rescue Errno::ECHILD
      FakeStatus.new(pid, 0, true, true)
    end
  end
end
