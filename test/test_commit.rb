require File.dirname(__FILE__) + '/helper'

class TestCommit < Test::Unit::TestCase
  def setup
    @r = Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
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
    assert_equal '80f136f', @r.commit('80f136f500dfdb8c3e8abf4ae716f875f0a1b57f').id_abbrev
  end

  # count

  def test_count
    assert_equal 107, Commit.count(@r, 'master')
  end

  # diff

  def test_diff
    # git diff --full-index 91169e1f5fa4de2eaea3f176461f5dc784796769 > test/fixtures/diff_p

    Git.any_instance.expects(:diff).with({:full_index => true}, 'master').returns(fixture('diff_p'))
    diffs = Commit.diff(@r, 'master')

    assert_equal 15, diffs.size

    assert_equal '.gitignore', diffs.first.a_path
    assert_equal '.gitignore', diffs.first.b_path
    assert_equal '4ebc8aea50e0a67e000ba29a30809d0a7b9b2666', diffs.first.a_blob.id
    assert_equal '2dd02534615434d88c51307beb0f0092f21fd103', diffs.first.b_blob.id
    assert_equal '100644', diffs.first.b_mode
    assert_equal false, diffs.first.new_file
    assert_equal false, diffs.first.deleted_file
    assert_equal "--- a/.gitignore\n+++ b/.gitignore\n@@ -1 +1,2 @@\n coverage\n+pkg", diffs.first.diff

    assert_equal 'lib/grit/actor.rb', diffs[5].a_path
    assert_equal nil, diffs[5].a_blob
    assert_equal 'f733bce6b57c0e5e353206e692b0e3105c2527f4', diffs[5].b_blob.id
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

  def test_diff_with_options
    Git.any_instance.expects(:diff).
      with({:full_index => true, :M => true}, 'master').
      returns(fixture('diff_mode_only'))
    Commit.diff(@r, 'master', nil, [], :M => true)
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
    assert_equal '4ebc8aea50e0a67e000ba29a30809d0a7b9b2666', diffs.first.a_blob.id
    assert_equal '2dd02534615434d88c51307beb0f0092f21fd103', diffs.first.b_blob.id
    assert_equal '100644', diffs.first.b_mode
    assert_equal false, diffs.first.new_file
    assert_equal false, diffs.first.deleted_file
    assert_equal "--- a/.gitignore\n+++ b/.gitignore\n@@ -1 +1,2 @@\n coverage\n+pkg", diffs.first.diff

    assert_equal 'lib/grit/actor.rb', diffs[5].a_path
    assert_equal nil, diffs[5].a_blob
    assert_equal 'f733bce6b57c0e5e353206e692b0e3105c2527f4', diffs[5].b_blob.id
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
    assert_equal nil, diffs.first.a_blob
    assert_equal nil, diffs.first.b_mode
    assert_equal '81d2c27608b352814cbe979a6acd678d30219678', diffs.first.b_blob.id
    assert_equal true, diffs.first.new_file
    assert_equal false, diffs.first.deleted_file
    assert_equal "--- /dev/null\n+++ b/History.txt\n@@ -0,0 +1,5 @@\n+== 1.0.0 / 2007-10-09\n+\n+* 1 major enhancement\n+  * Birthday!\n+", diffs.first.diff


    assert_equal 'lib/grit.rb', diffs[5].a_path
    assert_equal nil, diffs[5].a_blob
    assert_equal '32cec87d1e78946a827ddf6a8776be4d81dcf1d1', diffs[5].b_blob.id
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

  def test_diffs_with_mode_only_change
    Git.any_instance.expects(:diff).returns(fixture('diff_mode_only'))
    @c = Commit.create(@r, :id => '91169e1f5fa4de2eaea3f176461f5dc784796769')
    diffs = @c.diffs

    assert_equal 23, diffs.size
    assert_equal '100644', diffs[0].a_mode
    assert_equal '100755', diffs[0].b_mode
  end

  def test_diffs_with_options
    Git.any_instance.expects(:diff).
      with({:full_index => true, :M => true}, 
        '038af8c329ef7c1bae4568b98bd5c58510465493', 
        '91169e1f5fa4de2eaea3f176461f5dc784796769').
      returns(fixture('diff_mode_only'))
    @c = Commit.create(@r, :id => '91169e1f5fa4de2eaea3f176461f5dc784796769')
    @c.diffs :M => true
  end

  # to_s

  def test_to_s
    @c = Commit.create(@r, :id => 'abc')
    assert_equal "abc", @c.to_s
  end

  # to_patch

  def test_to_patch
    @c = Commit.create(@r, :id => '80f136f500dfdb8c3e8abf4ae716f875f0a1b57f')

    patch = @c.to_patch

    assert patch.include?('From 80f136f500dfdb8c3e8abf4ae716f875f0a1b57f Mon Sep 17 00:00:00 2001')
    assert patch.include?('From: tom <tom@taco.(none)>')
    assert patch.include?('Date: Tue, 20 Nov 2007 17:27:42 -0800')
    assert patch.include?('Subject: [PATCH] fix tests on other machines')
    assert patch.include?('test/test_reality.rb |   30 +++++++++++++++---------------')
    assert patch.include?('@@ -1,17 +1,17 @@')
    assert patch.include?('+#     recurse(t)')
    assert patch.include?("1.7.")
  end

  # patch_id
  
  def test_patch_id
    @c = Commit.create(@r, :id => '80f136f500dfdb8c3e8abf4ae716f875f0a1b57f')
    assert_equal '9450b04e4f83ad0067199c9e9e338197d1835cbb', @c.patch_id
  end

  # inspect

  def test_inspect
    @c = Commit.create(@r, :id => 'abc')
    assert_equal %Q{#<Grit::Commit "abc">}, @c.inspect
  end

  # to_hash

  def test_to_hash
    old_tz, ENV["TZ"] = ENV["TZ"], "US/Pacific"
    @c = Commit.create(@r, :id => '4c8124ffcf4039d292442eeccabdeca5af5c5017')
    date = Time.parse('Wed Oct 10 03:06:12 -0400 2007')
    expected = {
      'parents' => ['id' => "634396b2f541a9f2d58b00be1a07f0c358b999b3"],
      'committed_date' => date.xmlschema,
      'tree' => "672eca9b7f9e09c22dcb128c283e8c3c8d7697a4",
      'authored_date' => date.xmlschema,
      'committer' => {'email' => "tom@mojombo.com", 'name' => "Tom Preston-Werner"},
      'message' => "implement Grit#heads",
      'author' => {'email' => "tom@mojombo.com", 'name' => "Tom Preston-Werner"},
      'id' => "4c8124ffcf4039d292442eeccabdeca5af5c5017"
    }

    assert_equal expected, @c.to_hash
  ensure
    ENV["TZ"] = old_tz
  end
end
