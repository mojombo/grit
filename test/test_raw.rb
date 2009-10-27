require File.dirname(__FILE__) + '/helper'
require 'pp'

class TestFileIndex < Test::Unit::TestCase

  def setup
    @r = Grit::Repo.new(File.join(File.dirname(__FILE__), *%w[dot_git]), :is_bare => true)
    @tag = 'f0055fda16c18fd8b27986dbf038c735b82198d7'
  end

  def test_raw_tag
    tag = @r.git.ruby_git.get_object_by_sha1(@tag)
    assert_match Regexp.new('v0.7.0'),  tag.raw_content
  end

end