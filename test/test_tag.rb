require File.dirname(__FILE__) + '/helper'

class TestTag < Test::Unit::TestCase
  def setup
    @r = Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
  end

  # list_from_string

  def test_list_from_string
    tags = @r.tags

    assert_equal 5, tags.size
    assert_equal 'not_annotated', tags[1].name
    assert_equal 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a', tags[1].commit.id
  end

  # list_from_string_for_signed_tag

  def test_list_from_string_for_signed_tag
    tags = @r.tags

    assert_equal 'v0.7.0', tags[2].name
    assert_equal '7bcc0ee821cdd133d8a53e8e7173a334fef448aa', tags[2].commit.id
  end

  # list_from_string_for_annotated_tag

  def test_list_from_string_for_annotated_tag
    tags = @r.tags

    assert_equal 'annotated', tags.first.name
    assert_equal 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a', tags.first.commit.id
  end

  # list_from_string_for_packed_tag

  def test_list_from_string_for_packed_tag
    tags = @r.tags

    assert_equal 'packed', tags[4].name
    assert_equal 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a', tags[4].commit.id
  end

  # list_from_string_for_packed_annotated_tag

  def test_list_from_string_for_packed_annotated_tag
    tags = @r.tags

    assert_equal 'packed_annotated', tags[3].name
    assert_equal '7bcc0ee821cdd133d8a53e8e7173a334fef448aa', tags[3].commit.id
  end


  # inspect

  def test_inspect
    tag = @r.tags.last

    assert_equal %Q{#<Grit::Tag "#{tag.name}">}, tag.inspect
  end
end
