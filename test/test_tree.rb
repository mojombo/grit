require File.dirname(__FILE__) + '/helper'

class TestTree < Test::Unit::TestCase
  def setup
    @t = Tree.allocate
  end
  
  # content_from_string
  
  def test_content_from_string_tree_should_return_tree
    text = fixture('ls_tree_a').split("\n").last
    
    tree = @t.content_from_string(nil, text)
    
    assert_equal Tree, tree.class
    assert_equal "650fa3f0c17f1edb4ae53d8dcca4ac59d86e6c44", tree.id
    assert_equal "040000", tree.mode
    assert_equal "test", tree.name
  end
  
  def test_content_from_string_invalid_type_should_raise
    assert_raise(RuntimeError) do
      @t.content_from_string(nil, "040000 bogus 650fa3f0c17f1edb4ae53d8dcca4ac59d86e6c44	test")
    end
  end
end