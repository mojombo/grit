require File.dirname(__FILE__) + '/helper'

class TestTree < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
    @t = Tree.allocate
  end
  
  # contents
  
  def test_contents_should_cache
    Git.any_instance.expects(:ls_tree).returns(
      fixture('ls_tree_a'),
      fixture('ls_tree_b')
    ).times(2)
    tree = @r.tree('master')
    
    child = tree.contents.last
    
    child.contents
    child.contents
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