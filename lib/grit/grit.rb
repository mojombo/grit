class Grit
  attr_accessor :path
  
  # Create a new Grit instance
  #   +path+ is the path to either the root git directory or the bare git repo
  #
  # Examples
  #   g = Grit.new("/Users/tom/dev/grit")
  #   g = Grit.new("/Users/tom/public/grit.git")
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
  def description
    File.open(File.join(self.path, 'description')).read.chomp
  end
end