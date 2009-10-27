require File.dirname(__FILE__) + '/helper'

class TestTree < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
    @t = Tree.allocate
  end

  # contents
  def test_nosuch_tree
    t = @r.tree('blahblah')
    assert t.contents.is_a?(Array)
    assert t.is_a?(Tree)
  end

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

  def test_content_from_string_tree_should_return_blob
    text = fixture('ls_tree_b').split("\n").first

    tree = @t.content_from_string(nil, text)

    assert_equal Blob, tree.class
    assert_equal "aa94e396335d2957ca92606f909e53e7beaf3fbb", tree.id
    assert_equal "100644", tree.mode
    assert_equal "grit.rb", tree.name
  end

  def test_content_from_string_tree_should_return_submodule
    text = fixture('ls_tree_submodule').split("\n").first

    sm = @t.content_from_string(nil, text)

    assert_kind_of Submodule, sm
  end

  def test_content_from_string_invalid_type_should_raise
    assert_raise(RuntimeError) do
      @t.content_from_string(nil, "040000 bogus 650fa3f0c17f1edb4ae53d8dcca4ac59d86e6c44	test")
    end
  end

  # /

  def test_slash
    Git.any_instance.expects(:ls_tree).returns(
      fixture('ls_tree_a')
    )
    tree = @r.tree('master')

    assert_equal 'aa06ba24b4e3f463b3c4a85469d0fb9e5b421cf8', (tree/'lib').id
    assert_equal '8b1e02c0fb554eed2ce2ef737a68bb369d7527df', (tree/'README.txt').id
  end

  def test_slash_with_commits
    Git.any_instance.expects(:ls_tree).returns(
      fixture('ls_tree_commit')
    )
    tree = @r.tree('master')

    assert_equal 'd35b34c6e931b9da8f6941007a92c9c9a9b0141a', (tree/'bar').id
    assert_equal '2afb47bcedf21663580d5e6d2f406f08f3f65f19', (tree/'foo').id
    assert_equal 'f623ee576a09ca491c4a27e48c0dfe04be5f4a2e', (tree/'baz').id
  end

  # inspect

  def test_inspect
    @t = Tree.create(@r, :id => 'abc')
    assert_equal %Q{#<Grit::Tree "abc">}, @t.inspect
  end

  def test_basename
    @t = Tree.create(@r, :name => 'foo/bar')
    assert_equal "bar", @t.basename
  end
end