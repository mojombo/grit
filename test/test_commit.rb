require File.dirname(__FILE__) + '/helper'

class TestCommit < Test::Unit::TestCase
  def setup
    @r = Repo.new(GRIT_REPO)
  end
  
  # __bake__
  
  def test_bake
    Git.any_instance.expects(:rev_list).returns(fixture('rev_list_single'))
    @c = Commit.create(@r, :id => '4c8124ffcf4039d292442eeccabdeca5af5c5017')
    @c.author # bake
    
    assert_equal "Tom Preston-Werner", @c.author.name
    assert_equal "tom@mojombo.com", @c.author.email
  end
  
  # short_name
  
  def test_id_abbrev
    Git.any_instance.expects(:rev_parse).returns(fixture('rev_parse'))
    assert_equal '80f136f', @r.commit('80f136f500dfdb8c3e8abf4ae716f875f0a1b57f').id_abbrev
  end
  
  # diff
  
  def test_diff
    # git diff --full-index 91169e1f5fa4de2eaea3f176461f5dc784796769 > test/fixtures/diff_p
    
    Git.any_instance.expects(:diff).with({:full_index => true}, 'master').returns(fixture('diff_p'))
    diffs = Commit.diff(@r, 'master')
    
    assert_equal 15, diffs.size
    
    assert_equal '.gitignore', diffs.first.a_path
    assert_equal '.gitignore', diffs.first.b_path
    assert_equal '4ebc8aea50e0a67e000ba29a30809d0a7b9b2666', diffs.first.a_commit.id
    assert_equal '2dd02534615434d88c51307beb0f0092f21fd103', diffs.first.b_commit.id
    assert_equal '100644', diffs.first.mode
    assert_equal false, diffs.first.new_file
    assert_equal false, diffs.first.deleted_file
    assert_equal "--- a/.gitignore\n+++ b/.gitignore\n@@ -1 +1,2 @@\n coverage\n+pkg", diffs.first.diff
    
    assert_equal 'lib/grit/actor.rb', diffs[5].a_path
    assert_equal nil, diffs[5].a_commit
    assert_equal 'f733bce6b57c0e5e353206e692b0e3105c2527f4', diffs[5].b_commit.id
    assert_equal true, diffs[5].new_file
  end
  
  def test_diff_with_two_commits
    # git diff --full-index 59ddc32 13d27d5 > test/fixtures/diff_2
    Git.any_instance.expects(:diff).with({:full_index => true}, '59ddc32', '13d27d5').returns(fixture('diff_2'))
    diffs = Commit.diff(@r, '59ddc32', '13d27d5')
    
    assert_equal 3, diffs.size
    assert_equal %w(lib/grit/commit.rb test/fixtures/show_empty_commit test/test_commit.rb), diffs.collect { |d| d.a_path }
  end
  
  def test_diff_with_files
    # git diff --full-index 59ddc32 -- lib > test/fixtures/diff_f
    Git.any_instance.expects(:diff).with({:full_index => true}, '59ddc32', '--', 'lib').returns(fixture('diff_f'))
    diffs = Commit.diff(@r, '59ddc32', %w(lib))
    
    assert_equal 1, diffs.size
    assert_equal 'lib/grit/diff.rb', diffs.first.a_path
  end
  
  def test_diff_with_two_commits_and_files
    # git diff --full-index 59ddc32 13d27d5 -- lib > test/fixtures/diff_2f
    Git.any_instance.expects(:diff).with({:full_index => true}, '59ddc32', '13d27d5', '--', 'lib').returns(fixture('diff_2f'))
    diffs = Commit.diff(@r, '59ddc32', '13d27d5', %w(lib))
    
    assert_equal 1, diffs.size
    assert_equal 'lib/grit/commit.rb', diffs.first.a_path
  end

  # diffs
  def test_diffs
    # git diff --full-index 91169e1f5fa4de2eaea3f176461f5dc784796769 > test/fixtures/diff_p
    
    Git.any_instance.expects(:diff).returns(fixture('diff_p'))
    @c = Commit.create(@r, :id => '91169e1f5fa4de2eaea3f176461f5dc784796769')
    diffs = @c.diffs
    
    assert_equal 15, diffs.size
    
    assert_equal '.gitignore', diffs.first.a_path
    assert_equal '.gitignore', diffs.first.b_path
    assert_equal '4ebc8aea50e0a67e000ba29a30809d0a7b9b2666', diffs.first.a_commit.id
    assert_equal '2dd02534615434d88c51307beb0f0092f21fd103', diffs.first.b_commit.id
    assert_equal '100644', diffs.first.mode
    assert_equal false, diffs.first.new_file
    assert_equal false, diffs.first.deleted_file
    assert_equal "--- a/.gitignore\n+++ b/.gitignore\n@@ -1 +1,2 @@\n coverage\n+pkg", diffs.first.diff
    
    assert_equal 'lib/grit/actor.rb', diffs[5].a_path
    assert_equal nil, diffs[5].a_commit
    assert_equal 'f733bce6b57c0e5e353206e692b0e3105c2527f4', diffs[5].b_commit.id
    assert_equal true, diffs[5].new_file
  end

  def test_diffs_on_initial_import
    # git show --full-index 634396b2f541a9f2d58b00be1a07f0c358b999b3 > test/fixtures/diff_i

    Git.any_instance.expects(:show).with({:full_index => true, :pretty => 'raw'}, '634396b2f541a9f2d58b00be1a07f0c358b999b3').returns(fixture('diff_i'))
    @c = Commit.create(@r, :id => '634396b2f541a9f2d58b00be1a07f0c358b999b3')
    diffs = @c.diffs
    
    assert_equal 10, diffs.size
    
    assert_equal 'History.txt', diffs.first.a_path
    assert_equal 'History.txt', diffs.first.b_path
    assert_equal nil, diffs.first.a_commit
    assert_equal nil, diffs.first.mode
    assert_equal '81d2c27608b352814cbe979a6acd678d30219678', diffs.first.b_commit.id
    assert_equal true, diffs.first.new_file
    assert_equal false, diffs.first.deleted_file
    assert_equal "--- /dev/null\n+++ b/History.txt\n@@ -0,0 +1,5 @@\n+== 1.0.0 / 2007-10-09\n+\n+* 1 major enhancement\n+  * Birthday!\n+", diffs.first.diff

    
    assert_equal 'lib/grit.rb', diffs[5].a_path
    assert_equal nil, diffs[5].a_commit
    assert_equal '32cec87d1e78946a827ddf6a8776be4d81dcf1d1', diffs[5].b_commit.id
    assert_equal true, diffs[5].new_file
  end
  
  def test_diffs_on_initial_import_with_empty_commit
    Git.any_instance.expects(:show).with(
      {:full_index => true, :pretty => 'raw'}, 
      '634396b2f541a9f2d58b00be1a07f0c358b999b3'
    ).returns(fixture('show_empty_commit'))
    
    @c = Commit.create(@r, :id => '634396b2f541a9f2d58b00be1a07f0c358b999b3')
    diffs = @c.diffs
    
    assert_equal [], diffs
  end
  
  # to_s
  
  def test_to_s
    @c = Commit.create(@r, :id => 'abc')
    assert_equal "abc", @c.to_s
  end
  
  # inspect
  
  def test_inspect
    @c = Commit.create(@r, :id => 'abc')
    assert_equal %Q{#<Grit::Commit "abc">}, @c.inspect
  end
end
