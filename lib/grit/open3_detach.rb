module Open3
  extend self

  def popen3(*cmd)
    pw = IO::pipe   # pipe[0] for read, pipe[1] for write
    pr = IO::pipe
    pe = IO::pipe

    pid = fork{
      # child
      fork{
        # grandchild
        pw[1].close
        STDIN.reopen(pw[0])
        pw[0].close

        pr[0].close
        STDOUT.reopen(pr[1])
        pr[1].close

        pe[0].close
        STDERR.reopen(pe[1])
        pe[1].close

        exec(*cmd)
      }
      exit!(0)
    }

    pw[0].close
    pr[1].close
    pe[1].close
    Process.waitpid(pid)
    pi = [pw[1], pr[0], pe[0]]
    pw[1].sync = true
    if defined? yield
      begin
        return yield(*pi)
      ensure
        Process.detach(pid) if pid
        pi.each { |p| p.close unless p.closed? }
      end
    end
    pi
  end
end
