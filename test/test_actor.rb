require File.dirname(__FILE__) + '/helper'

class TestActor < Test::Unit::TestCase
  def setup

  end

  # from_string

  def test_from_string_should_separate_name_and_email
    a = Actor.from_string("Tom Werner <tom@example.com>")
    assert_equal "Tom Werner", a.name
    assert_equal "tom@example.com", a.email
  end

  def test_from_string_should_handle_just_name
    a = Actor.from_string("Tom Werner")
    assert_equal "Tom Werner", a.name
    assert_equal nil, a.email
  end

  # inspect

  def test_inspect
    a = Actor.from_string("Tom Werner <tom@example.com>")
    assert_equal %Q{#<Grit::Actor "Tom Werner <tom@example.com>">}, a.inspect
  end

  # to_s

  def test_to_s_should_alias_name
    a = Actor.from_string("Tom Werner <tom@example.com>")
    assert_equal a.name, a.to_s
  end
end
