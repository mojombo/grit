require File.dirname(__FILE__) + '/helper'

# This tests creating a tag object without creating a corresponding ref.

class TestCreateTag < Test::Unit::TestCase
  def with_test_repo
    temp_repo("dot_git") do |repo_path|
      yield Grit::Repo.new(repo_path, :is_bare => true)
    end
  end

  def find_tag_by_sha(repo, sha)
    Grit::Tag.parse_tag_data(repo.git.get_raw_object(sha))
  end

  def test_create_tag_with_no_tagger
    with_test_repo do |repo|
      master_sha = repo.get_head("master").commit.sha

      tag_sha = Grit::Tag.create_tag_object(repo, {
        :object => master_sha,
        :type   => "commit",
        :tag    => "tag_of_master"
      })

      assert_not_nil tag_sha

      tag = find_tag_by_sha(repo, tag_sha)

      assert_not_nil tag
      assert_not_nil tag[:tag_date]
      assert_equal "tag_of_master", tag[:tag]
      assert_equal master_sha,      tag[:object]
      assert_equal "commit",        tag[:type]
      assert_equal "none",          tag[:tagger].name
      assert_equal "none@none",     tag[:tagger].email
      assert_equal "",              tag[:message]
    end
  end

  def test_create_tag_with_tagger
    with_test_repo do |repo|
      master_sha = repo.get_head("master").commit.sha

      tag_sha = Grit::Tag.create_tag_object(repo, {
        :object => master_sha,
        :type   => "commit",
        :tag    => "tag_of_master",
        :tagger => {
          :name  => "Scott Chacon",
          :email => "schacon@gmail.com",
          :date  => Time.utc(2012, 1, 1).to_s
        }
      })

      assert_not_nil tag_sha

      tag = find_tag_by_sha(repo, tag_sha)

      assert_not_nil tag
      assert_equal "tag_of_master",      tag[:tag]
      assert_equal master_sha,           tag[:object]
      assert_equal "commit",             tag[:type]
      assert_equal "Scott Chacon",       tag[:tagger].name
      assert_equal "schacon@gmail.com",  tag[:tagger].email
      assert_equal Time.utc(2012, 1, 1), tag[:tag_date]
      assert_equal "",                   tag[:message]
    end
  end

  def test_create_tag_with_message
    with_test_repo do |repo|
      master_sha = repo.get_head("master").commit.sha

      tag_sha = Grit::Tag.create_tag_object(repo, {
        :object  => master_sha,
        :type    => "commit",
        :tag     => "tag_of_master",
        :message => "test message"
      })

      assert_not_nil tag_sha

      tag = find_tag_by_sha(repo, tag_sha)

      assert_not_nil tag
      assert_not_nil tag[:tag_date]
      assert_equal "tag_of_master", tag[:tag]
      assert_equal master_sha,      tag[:object]
      assert_equal "commit",        tag[:type]
      assert_equal "none",          tag[:tagger].name
      assert_equal "none@none",     tag[:tagger].email
      assert_equal "test message",  tag[:message]
    end
  end

  def test_create_with_bad_object
    with_test_repo do |repo|
      assert_raises(Grit::Git::CommandFailed) do
        Grit::Tag.create_tag_object(repo, {
          :object => "deadbeef" * 5,
          :type   => "commit",
          :tag    => "tag_of_nonsense"
        })
      end
    end
  end

  def test_create_with_type_mismatch
    with_test_repo do |repo|
      assert_raises(Grit::Git::CommandFailed) do
        Grit::Tag.create_tag_object(repo, {
          :object => repo.get_head("master").commit.sha,
          :type   => "blob",
          :tag    => "tag_of_wrong_type"
        })
      end
    end
  end
end
