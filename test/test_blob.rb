require File.dirname(__FILE__) + '/helper'

class TestBlob < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
    @b = Blob.allocate
  end

  # blob
  def test_nosuch_blob
    t = @r.blob('blahblah')
    assert t.is_a?(Blob)
  end

  def test_data_should_return_blob_contents
    Git.any_instance.expects(:cat_file).returns(fixture('cat_file_blob'))
    blob = Blob.create(@r, :id => 'abc')
    assert_equal "Hello world", blob.data
  end

  def test_data_should_cache
    Git.any_instance.expects(:cat_file).returns(fixture('cat_file_blob')).times(1)
    blob = Blob.create(@r, :id => 'abc')
    blob.data
    blob.data
  end

  # size

  def test_size_should_return_file_size
    Git.any_instance.expects(:cat_file).returns(fixture('cat_file_blob_size'))
    blob = Blob.create(@r, :id => 'abc')
    assert_equal 11, blob.size
  end

  # data

  # mime_type

  def test_mime_type_should_return_mime_type_for_known_types
    blob = Blob.create(@r, :id => 'abc', :name => 'foo.png')
    assert_equal "image/png", blob.mime_type
  end

  def test_mime_type_should_return_text_plain_for_unknown_types
    blob = Blob.create(@r, :id => 'abc')
    assert_equal "text/plain", blob.mime_type
  end

  # blame

  def test_blame
    Git.any_instance.expects(:blame).returns(fixture('blame'))
    b = Blob.blame(@r, 'master', 'lib/grit.rb')
    assert_equal 13, b.size
    assert_equal 25, b.inject(0) { |acc, x| acc + x.last.size }
    assert_equal b[0].first.object_id, b[9].first.object_id
    c = b.first.first
    c.expects(:__bake__).times(0)
    assert_equal '634396b2f541a9f2d58b00be1a07f0c358b999b3', c.id
    assert_equal 'Tom Preston-Werner', c.author.name
    assert_equal 'tom@mojombo.com', c.author.email
    assert_equal Time.at(1191997100), c.authored_date
    assert_equal 'Tom Preston-Werner', c.committer.name
    assert_equal 'tom@mojombo.com', c.committer.email
    assert_equal Time.at(1191997100), c.committed_date
    assert_equal 'initial grit setup', c.message
    # c.expects(:__bake__).times(1)
    # assert_equal Tree, c.tree.class
  end

  # inspect

  def test_inspect
    @b = Blob.create(@r, :id => 'abc')
    assert_equal %Q{#<Grit::Blob "abc">}, @b.inspect
  end

  def test_basename
    @b = Blob.create(@r, :name => 'foo/bar.rb')
    assert_equal "bar.rb", @b.basename
  end
end