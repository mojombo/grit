require File.dirname(__FILE__) + '/helper'

class TestGit < Test::Unit::TestCase
  def setup
    @git = Git.new(File.join(File.dirname(__FILE__), *%w[..]))
  end
  
  def test_method_missing
    assert_match /^git version [\d\.]*$/, @git.version
  end
  
  def test_transform_options
    assert_equal ["--max-count=5"], @git.transform_options({:max_count => 5})
  end
end