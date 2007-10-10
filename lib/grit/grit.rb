class Grit
  class << self
    attr_accessor :git_binary
  end
  
  self.git_binary = "/usr/bin/env git"
  
  # The path of the git repo as a String
  attr_accessor :path
  
  # Create a new Grit instance
  #   +path+ is the path to either the root git directory or the bare git repo
  #
  # Examples
  #   g = Grit.new("/Users/tom/dev/grit")
  #   g = Grit.new("/Users/tom/public/grit.git")
  #
  # Returns Grit
  def initialize(path)
    if File.exist?(File.join(path, '.git'))
      self.path = File.join(path, '.git')
    elsif File.exist?(path) && path =~ /\.git$/
      self.path = path
    else
      raise InvalidGitRepositoryError.new(path) unless File.exist?(path)
    end
  end
  
  # Return the project's description. Taken verbatim from REPO/description
  #
  # Returns String
  def description
    File.open(File.join(self.path, 'description')).read.chomp
  end
  
  # Return an array of Head objects representing the available heads in
  # this repo
  #
  # Returns Grit::Head[]
  def heads
    output = git("for-each-ref",
                 # "--count=1",
                 "--sort=-committerdate",
                 "--format='%(objectname) %(refname) %(subject)%00%(committer)'",
                 "refs/heads")
                 
    heads = []
    
    output.split("\n").each do |line|
      ref_info, committer_info = line.split("\0")
      id, name, message = ref_info.split(" ", 3)
      m, committer, epoch, tz = *committer_info.match(/^(.*) ([0-9]+) (.*)$/)
      date = Time.at(epoch.to_i)
      heads << Head.new(id, name, message, committer, date)
    end
    
    heads
  end
  
  # private
  
  # Run the given git command with the specified arguments and return
  # the result as a chomped String
  #   +cmd+ is the command
  #   +args+ is the list of arguments (to be joined by spaces)
  #
  # Returns String
  def git(cmd, *args)
    `#{Grit.git_binary} #{cmd} #{args.join(' ')}`.chomp
  end
end