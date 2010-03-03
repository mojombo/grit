require File.dirname(__FILE__) + '/helper'

class TestRepo < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end

  def create_temp_repo(clone_path)
    filename = 'git_test' + Time.now.to_i.to_s + rand(300).to_s.rjust(3, '0')
    tmp_path = File.join("/tmp/", filename)
    FileUtils.mkdir_p(tmp_path)
    FileUtils.cp_r(clone_path, tmp_path)
    File.join(tmp_path, 'dot_git')
  end

  def test_update_refs_packed
    gpath = create_temp_repo(File.join(File.dirname(__FILE__), *%w[dot_git]))
    @git = Grit::Repo.new(gpath, :is_bare => true)

    # new and existing
    test   = 'ac9a30f5a7f0f163bbe3b6f0abf18a6c83b06872'
    master = 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a'

    @git.update_ref('testref', test)
    new_t = @git.get_head('testref').commit.sha
    assert new_t != master

    @git.update_ref('master', test)
    new_m = @git.get_head('master').commit.sha
    assert new_m != master

    old = @git.get_head('nonpack').commit.sha
    @git.update_ref('nonpack', test)
    newp = @git.get_head('nonpack').commit.sha
    assert newp != old

    FileUtils.rm_r(gpath)
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
    assert @r.description.include?("Unnamed repository; edit this file")
  end

  # refs

  def test_refs_should_return_array_of_ref_objects
    @r.refs.each do |ref|
      assert ref.is_a?(Grit::Ref)
    end
  end

  # heads

  def test_current_head
    @r = Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
    head = @r.head
    assert_equal Grit::Head, head.class
    assert_equal 'master', head.name
    assert_equal 'ca8a30f5a7f0f163bbe3b6f0abf18a6c83b0687a', @r.commits(head.name).first.id
  end

  def test_heads_should_return_array_of_head_objects
    @r.heads.each do |head|
      assert_equal Grit::Head, head.class
    end
  end

  def test_heads_should_populate_head_data
    @r = Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
    head = @r.heads[1]

    assert_equal 'test/master', head.name
    assert_equal '2d3acf90f35989df8f262dc50beadc4ee3ae1560', head.commit.id
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
    assert_equal "Merge branch 'site'\n\n  * Some other stuff\n  * just one more", c.message
    assert_equal "Merge branch 'site'", c.short_message
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
    FileUtils.stubs(:mkdir_p)

    Git.any_instance.expects(:init).returns(true)
    Repo.expects(:new).with("/foo/bar.git", {})
    Repo.init_bare("/foo/bar.git")
  end

  def test_init_bare_with_options
    FileUtils.stubs(:mkdir_p)

    Git.any_instance.expects(:init).with(
      :bare => true, :template => "/baz/sweet").returns(true)
    Repo.expects(:new).with("/foo/bar.git", {})
    Repo.init_bare("/foo/bar.git", :template => "/baz/sweet")
  end

  # fork_bare

  def test_fork_bare
    FileUtils.stubs(:mkdir_p)

    Git.any_instance.expects(:clone).with(
      {:bare => true, :shared => true},
      "#{absolute_project_path}/.git",
      "/foo/bar.git").returns(nil)
    Repo.expects(:new)

    @r.fork_bare("/foo/bar.git")
  end

  def test_fork_bare_with_options
    FileUtils.stubs(:mkdir_p)

    Git.any_instance.expects(:clone).with(
      {:bare => true, :shared => true, :template => '/awesome'},
      "#{absolute_project_path}/.git",
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
    #@r.archive_tar  -- no assertion being done here
  end

  # archive_tar_gz

  def test_archive_tar_gz
    #@r.archive_tar_gz -- again, no assertion
  end

  # enable_daemon_serve

  def test_enable_daemon_serve
    f = stub
    f.expects("write").with('')
    File.expects(:open).with(File.join(@r.path, 'git-daemon-export-ok'), 'w').yields(f)
    @r.enable_daemon_serve
  end

  # disable_daemon_serve

  def test_disable_daemon_serve
    FileUtils.expects(:rm_rf).with(File.join(@r.path, 'git-daemon-export-ok'))
    @r.disable_daemon_serve
  end

  def test_gc_auto
    Git.any_instance.expects(:gc).with({:auto => true})
    @r.gc_auto
  end

  # alternates

  def test_alternates_with_two_alternates
    File.expects(:exist?).with("#{absolute_project_path}/.git/objects/info/alternates").returns(true)
    File.expects(:read).with("#{absolute_project_path}/.git/objects/info/alternates").returns("/path/to/repo1/.git/objects\n/path/to/repo2.git/objects\n")

    assert_equal ["/path/to/repo1/.git/objects", "/path/to/repo2.git/objects"], @r.alternates
  end

  def test_alternates_no_file
    File.expects(:exist?).returns(false)

    assert_equal [], @r.alternates
  end

  # alternates=

  def test_alternates_setter_ok
    alts = %w{/path/to/repo.git/objects /path/to/repo2.git/objects}

    alts.each do |alt|
      File.expects(:exist?).with(alt).returns(true)
    end

    File.any_instance.expects(:write).with(alts.join("\n"))

    assert_nothing_raised do
      @r.alternates = alts
    end
  end

  def test_alternates_setter_bad
    alts = %w{/path/to/repo.git/objects}

    alts.each do |alt|
      File.expects(:exist?).with(alt).returns(false)
    end

    File.any_instance.expects(:write).never

    assert_raise RuntimeError do
      @r.alternates = alts
    end
  end

  def test_alternates_setter_empty
    File.any_instance.expects(:write)
    @r.alternates = []
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

  # commit_deltas_from

  def test_commit_deltas_from_nothing_new
    other_repo = Repo.new(GRIT_REPO)
    @r.git.expects(:rev_list).with({}, "master").returns(fixture("rev_list_delta_b"))
    other_repo.git.expects(:rev_list).with({}, "master").returns(fixture("rev_list_delta_a"))

    delta_blobs = @r.commit_deltas_from(other_repo)
    assert_equal 0, delta_blobs.size
  end

  def test_commit_deltas_from_when_other_has_new
    other_repo = Repo.new(GRIT_REPO)
    @r.git.expects(:rev_list).with({}, "master").returns(fixture("rev_list_delta_a"))
    other_repo.git.expects(:rev_list).with({}, "master").returns(fixture("rev_list_delta_b"))
    %w[
      4c8124ffcf4039d292442eeccabdeca5af5c5017
      634396b2f541a9f2d58b00be1a07f0c358b999b3
      ab25fd8483882c3bda8a458ad2965d2248654335
    ].each do |ref|
      Commit.expects(:find_all).with(other_repo, ref, :max_count => 1).returns([stub()])
    end
    delta_blobs = @r.commit_deltas_from(other_repo)
    assert_equal 3, delta_blobs.size
  end

  # object_exist

  def test_select_existing_objects
    before = ['634396b2f541a9f2d58b00be1a07f0c358b999b3', 'deadbeef']
    after = ['634396b2f541a9f2d58b00be1a07f0c358b999b3']
    assert_equal after, @r.git.select_existing_objects(before)
  end
end
