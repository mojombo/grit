require File.dirname(__FILE__) + '/helper'

class TestBlob < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
    @b = Blob.allocate
  end
  
  # blob
  
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
  
  def test_data_should_return_blob_contents
    Git.any_instance.expects(:cat_file).returns(fixture('cat_file_blob_size'))
    blob = Blob.create(@r, :id => 'abc')
    assert_equal 11, blob.size
  end
  
  # inspect
  
  def test_inspect
    @b = Blob.create(@r, :id => 'abc')
    assert_equal %Q{#<Grit::Blob "abc">}, @b.inspect
  end
end