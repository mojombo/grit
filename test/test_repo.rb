require File.dirname(__FILE__) + '/helper'

class TestRepo < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end
  
  # new
  
  def test_new_should_raise_on_invalid_repo_location
    assert_raise(InvalidGitRepositoryError) do
      Repo.new("/tmp")
    end
  end
  
  def test_new_should_raise_on_non_existant_path
    assert_raise(NoSuchPathError) do
      Repo.new("/foobar")
    end
  end
  
  # descriptions
  
  def test_description
    assert_equal "Unnamed repository; edit this file to name it for gitweb.", @r.description
  end
  
  # heads
  
  def test_heads_should_return_array_of_head_objects
    @r.heads.each do |head|
      assert_equal Grit::Head, head.class
    end
  end
  
  def test_heads_should_populate_head_data
    Git.any_instance.expects(:for_each_ref).returns(fixture('for_each_ref'))
    
    head = @r.heads.first
    
    assert_equal 'master', head.name
    assert_equal '634396b2f541a9f2d58b00be1a07f0c358b999b3', head.commit.id
  end
  
  # branches
  
  def test_branches
    # same as heads
  end
  
  # commits
  
  def test_commits
    Git.any_instance.expects(:rev_list).returns(fixture('rev_list'))
    
    commits = @r.commits('master', 10)
    
    c = commits[0]
    assert_equal '4c8124ffcf4039d292442eeccabdeca5af5c5017', c.id
    assert_equal ["634396b2f541a9f2d58b00be1a07f0c358b999b3"], c.parents.map { |p| p.id }
    assert_equal "672eca9b7f9e09c22dcb128c283e8c3c8d7697a4", c.tree.id
    assert_equal "Tom Preston-Werner", c.author.name
    assert_equal "tom@mojombo.com", c.author.email
    assert_equal Time.at(1191999972), c.authored_date
    assert_equal "Tom Preston-Werner", c.committer.name
    assert_equal "tom@mojombo.com", c.committer.email
    assert_equal Time.at(1191999972), c.committed_date
    assert_equal "implement Grit#heads", c.message
    
    c = commits[1]
    assert_equal [], c.parents
    
    c = commits[2]
    assert_equal ["6e64c55896aabb9a7d8e9f8f296f426d21a78c2c", "7f874954efb9ba35210445be456c74e037ba6af2"], c.parents.map { |p| p.id }
    assert_equal "Merge branch 'site'", c.message
  end
  
  # commit_count
  
  def test_commit_count
    Git.any_instance.expects(:rev_list).with({}, 'master').returns(fixture('rev_list_count'))
    
    assert_equal 655, @r.commit_count('master')
  end
  
  # commit
  
  def test_commit
    commit = @r.commit('634396b2f541a9f2d58b00be1a07f0c358b999b3')
    
    assert_equal "634396b2f541a9f2d58b00be1a07f0c358b999b3", commit.id
  end
  
  # tree
  
  def test_tree
    Git.any_instance.expects(:ls_tree).returns(fixture('ls_tree_a'))
    tree = @r.tree('master')
    
    assert_equal 4, tree.contents.select { |c| c.instance_of?(Blob) }.size
    assert_equal 3, tree.contents.select { |c| c.instance_of?(Tree) }.size
  end
  
  # blob
  
  def test_blob
    Git.any_instance.expects(:cat_file).returns(fixture('cat_file_blob'))
    blob = @r.blob("abc")
    assert_equal "Hello world", blob.data
  end
  
  # init_bare
  
  def test_init_bare
    Git.any_instance.expects(:init).returns(true)
    Repo.expects(:new).with("/foo/bar.git")
    Repo.init_bare("/foo/bar.git")
  end
  
  def test_init_bare_with_options
    Git.any_instance.expects(:init).with(
      :template => "/baz/sweet").returns(true)
    Repo.expects(:new).with("/foo/bar.git")
    Repo.init_bare("/foo/bar.git", :template => "/baz/sweet")
  end
  
  # fork_bare
  
  def test_fork_bare
    Git.any_instance.expects(:clone).with(
      {:bare => true, :shared => true}, 
      '/Users/tom/dev/mojombo/grit/.git',
      "/foo/bar.git").returns(nil)
    Repo.expects(:new)
      
    @r.fork_bare("/foo/bar.git")
  end
  
  def test_fork_bare_with_options
    Git.any_instance.expects(:clone).with(
      {:bare => true, :shared => true, :template => '/awesome'}, 
      '/Users/tom/dev/mojombo/grit/.git',
      "/foo/bar.git").returns(nil)
    Repo.expects(:new)
      
    @r.fork_bare("/foo/bar.git", :template => '/awesome')
  end
  
  # diff
  
  def test_diff
    Git.any_instance.expects(:diff).with({}, 'master^', 'master', '--')
    @r.diff('master^', 'master')
    
    Git.any_instance.expects(:diff).with({}, 'master^', 'master', '--', 'foo/bar')
    @r.diff('master^', 'master', 'foo/bar')
    
    Git.any_instance.expects(:diff).with({}, 'master^', 'master', '--', 'foo/bar', 'foo/baz')
    @r.diff('master^', 'master', 'foo/bar', 'foo/baz')
  end
  
  # commit_diff
  
  def test_diff
    Git.any_instance.expects(:diff).returns(fixture('diff_p'))
    diffs = @r.commit_diff('master')
    
    assert_equal 15, diffs.size
  end
  
  # init bare
  
  # archive
  
  def test_archive_tar
    @r.archive_tar
  end
  
  # archive_tar_gz
  
  def test_archive_tar_gz
    @r.archive_tar_gz
  end
  
  # enable_daemon_serve
  
  def test_enable_daemon_serve
    FileUtils.expects(:touch).with(File.join(@r.path, '.git', 'git-daemon-export-ok'))
    @r.enable_daemon_serve
  end
  
  # disable_daemon_serve
  
  def test_disable_daemon_serve
    FileUtils.expects(:rm_f).with(File.join(@r.path, '.git', 'git-daemon-export-ok'))
    @r.disable_daemon_serve
  end
  
  # inspect
  
  def test_inspect
    assert_equal %Q{#<Grit::Repo "#{File.expand_path(GRIT_REPO)}/.git">}, @r.inspect
  end

  # log

  def test_log
    Git.any_instance.expects(:log).times(2).with({:pretty => 'raw'}, 'master').returns(fixture('rev_list'))

    assert_equal '4c8124ffcf4039d292442eeccabdeca5af5c5017', @r.log.first.id
    assert_equal 'ab25fd8483882c3bda8a458ad2965d2248654335', @r.log.last.id
  end

  def test_log_with_path_and_options
    Git.any_instance.expects(:log).with({:pretty => 'raw', :max_count => 1}, 'master', '--', 'file.rb').returns(fixture('rev_list'))
    @r.log('master', 'file.rb', :max_count => 1)
  end
end
