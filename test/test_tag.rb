require File.dirname(__FILE__) + '/helper'

class TestTag < Test::Unit::TestCase
  def setup
    @r = Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
    @tags = {}
    @r.tags.each {|t| @tags[t.name] = t}
  end

  # list_from_string size

  def test_list_from_string_size
    assert_equal 5, @r.tags.size
  end

  # list_from_string

  def test_list_from_string
    tag = @tags['not_annotated']

    assert_equal 'not_annotated', tag.name
    assert_equal 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a', tag.commit.id
  end

  # list_from_string_for_signed_tag

  def test_list_from_string_for_signed_tag
    tag = @tags['v0.7.0']

    assert_equal 'v0.7.0', tag.name
    assert_equal '7bcc0ee821cdd133d8a53e8e7173a334fef448aa', tag.commit.id
  end

  # list_from_string_for_annotated_tag

  def test_list_from_string_for_annotated_tag
    tag = @tags['annotated']

    assert_equal 'annotated', tag.name
    assert_equal 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a', tag.commit.id
  end

  # list_from_string_for_packed_tag

  def test_list_from_string_for_packed_tag
    tag = @tags['packed']

    assert_equal 'packed', tag.name
    assert_equal 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a', tag.commit.id
  end

  # list_from_string_for_packed_annotated_tag

  def test_list_from_string_for_packed_annotated_tag
    tag = @tags['packed_annotated']

    assert_equal 'packed_annotated', tag.name
    assert_equal '7bcc0ee821cdd133d8a53e8e7173a334fef448aa', tag.commit.id
  end

  # describe_recent_tag

  def test_describe_recent_tag
    assert_equal 'annotated', @r.recent_tag_name
  end

  # describe_recent_tag_with_updates

  def test_describe_recent_tag_with_updates
    assert_equal 'v0.7.0-62-g3fa4e13', @r.recent_tag_name('3fa4e130fa18c92e3030d4accb5d3e0cadd40157')
  end

  # describe_missing_tag

  def test_describe_missing_Tag
    assert_nil @r.recent_tag_name('boom')
  end

  # reads_light_tag_contents

  def test_reads_light_tag_contents
    tag = @tags['not_annotated']
    assert_equal 'not_annotated', tag.name
    assert_equal 'added a pure-ruby git library and converted the cat_file commands to use it',
      tag.message
    assert_equal 'Scott Chacon',      tag.tagger.name
    assert_equal 'schacon@gmail.com', tag.tagger.email
    assert_equal Time.utc(2008, 4, 18, 23, 27, 8), tag.tag_date.utc
  end

  # reads_annotated_tag_contents

  def test_reads_annotated_tag_contents
    tag = @tags['annotated']
    assert_equal 'annotated',       tag.name
    assert_equal 'Annotated tag.',  tag.message
    assert_equal 'Chris Wanstrath', tag.tagger.name
    assert_equal 'chris@ozmm.org',  tag.tagger.email
    assert_equal Time.utc(2009, 2, 13, 22, 22, 16), tag.tag_date.utc
  end

  def test_parses_tag_object_without_message
    parsed = Grit::Tag.parse_tag_data(<<-TAG)
object 2695effb5807a22ff3d138d593fd856244e155e7
type commit
tag rel-0-1-0
tagger bob <bob>
Thu Jan 1 00:00:00 1970 +0000
TAG
    assert_equal 'bob',          parsed[:tagger].name
    assert_equal Time.utc(1970), parsed[:tag_date]
    assert_equal '',             parsed[:message]
  end

  # reads_annotated_and_packed_tag_contents

  def test_reads_annotated_and_packed_tag_contents
    tag = @tags['packed_annotated']
    assert_equal 'packed_annotated',   tag.name
    assert_equal 'v0.7.0',             tag.message
    assert_equal 'Tom Preston-Werner', tag.tagger.name
    assert_equal 'tom@mojombo.com',    tag.tagger.email
    assert_equal Time.utc(2008, 1, 8, 5, 32, 29), tag.tag_date.utc
  end

  # inspect

  def test_inspect
    tag = @tags['v0.7.0']

    assert_equal %Q{#<Grit::Tag "#{tag.name}">}, tag.inspect
  end
end
