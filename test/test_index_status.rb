require File.dirname(__FILE__) + '/helper'

class TestIndexStatus < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end

  def test_add
    Git.any_instance.expects(:add).with({}, 'file1', 'file2')
    @r.add('file1', 'file2')
  end

  def test_add_array
    Git.any_instance.expects(:add).with({}, 'file1', 'file2')
    @r.add(['file1', 'file2'])
  end

  def test_remove
    Git.any_instance.expects(:rm).with({}, 'file1', 'file2')
    @r.remove('file1', 'file2')
  end

  def test_remove_array
    Git.any_instance.expects(:rm).with({}, 'file1', 'file2')
    @r.remove(['file1', 'file2'])
  end

  def test_status
    Git.any_instance.expects(:diff_index).with({}, 'HEAD').returns(fixture('diff_index'))
    Git.any_instance.expects(:diff_files).returns(fixture('diff_files'))
    Git.any_instance.expects(:ls_files).with({:stage => true}).returns(fixture('ls_files'))
    status = @r.status
    stat = status['lib/grit/repo.rb']
    assert_equal stat.sha_repo, "71e930d551c413a123f43e35c632ea6ba3e3705e"
    assert_equal stat.mode_repo, "100644"
    assert_equal stat.type, "M"
  end


end