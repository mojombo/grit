require File.dirname(__FILE__) + '/helper'

class TestActor < Test::Unit::TestCase
  def setup

  end

  # output
  def test_output_adds_tz_offset
    # Mock time object which is in India Standard Time, at a UTC offset of
    # +05:30.  We cannot construct a real time value with a given offset
    # because Ruby's Time class can only represent local time or GMT.
    t = stub(:to_i => 1234567, :utc_offset => 19800)
    a = Actor.new("Tom Werner", "tom@example.com")
    assert_equal "Tom Werner <tom@example.com> #{t.to_i} +0530",
      a.output(t)

    # Make sure negative offests work too
    t = stub(:to_i => 1234567, :utc_offset => -19800)
    assert_equal "Tom Werner <tom@example.com> #{t.to_i} -0530",
      a.output(t)    
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
