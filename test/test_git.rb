require File.dirname(__FILE__) + '/helper'

class TestGit < Test::Unit::TestCase
  
  def test_method_missing
    assert_match /^git version [\d\.]*$/, Git.version
  end
end