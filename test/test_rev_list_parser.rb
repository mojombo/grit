require File.dirname(__FILE__) + '/helper'

class TestRevListParser < Test::Unit::TestCase
  def test_parsing_single_commit
    sha = '671d0b0a85af271395eb71ff91f942f54681b144'
    r = repo(:dot_git_signed_tag_merged)
    rev_list = r.git.rev_list({:pretty => "raw", :max_count => 1}, sha)

    parser = Grit::RevListParser.new(rev_list)
    assert_equal 1, parser.entries.size
    assert entry = parser.entries.first
    assert_equal "Merge tag 'v1.1' into bar", entry.message_lines.first
    assert_equal '671d0b0a85af271395eb71ff91f942f54681b144', entry.commit
    assert_equal 'a9ac6c1e58bbdd7693e49ce34b32d9b0b53c0bcf', entry.tree
    assert_equal [
      'dce37589cfa5748900d05ab07ee2af5010866838', 'b2b1760347d797f3dc79360d487b9afa7baafd6a'],
      entry.parents

    assert_match /^Jonathan /, entry.author
    assert_match /^Jonathan /, entry.committer
    assert_equal 'object b2b1760347d797f3dc79360d487b9afa7baafd6a', entry.meta[:mergetag].to_s
  end

  def test_parsing_multiple_commits
    r = repo(:dot_git_signed_tag_merged)
    rev_list = r.git.rev_list({:pretty => "raw", :all => true})

    parser = Grit::RevListParser.new(rev_list)
    shas = %w(671d0b0a85af271395eb71ff91f942f54681b144
              dce37589cfa5748900d05ab07ee2af5010866838
              b2b1760347d797f3dc79360d487b9afa7baafd6a
              2ae8b20538f5d358e97978632965efc380c42c9a)
    shas.each_with_index do |sha, idx|
      assert entry = parser.entries[idx], "no entry for commit #{idx+1}"
      assert_equal sha, entry.commit, "different sha for commit #{idx+1}"
    end
    assert_equal 4, parser.entries.size
  end

  def test_parsing_multiple_commits_with_empty_message
    r = repo(:dot_git_empty_messages)
    rev_list = r.git.rev_list({:pretty => "raw", :all => true})

    parser = Grit::RevListParser.new(rev_list)
    shas = %w(4a295262f134e3b97b3988d631e3bd9f9b132c8a
              c01a96da0c12a4c49260cefa744b34c53a0c7c68)
    shas.each_with_index do |sha, idx|
      assert entry = parser.entries[idx], "no entry for commit #{idx+1}"
      assert_equal sha, entry.commit, "different sha for commit #{idx+1}"
    end
    assert_equal 2, parser.entries.size
  end

  def repo(name)
    Repo.new(File.join(File.dirname(__FILE__), name.to_s), :is_bare => true)
  end
end

