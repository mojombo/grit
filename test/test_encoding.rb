# encoding: UTF-8

require File.dirname(__FILE__) + '/helper'

class TestEncoding < Test::Unit::TestCase
  def test_nil_message
    message = GritExt.encode! nil
    assert_equal message, nil
  end

  def test_binary_message
    message = "\xFF\xD8\xFF\xE0"
    encoded_message = GritExt.encode!(message)
    assert_equal encoded_message.bytes.to_a, message.bytes.to_a
    assert_equal message.encoding.name, "UTF-8"
  end

  def test_invalid_encoding
    message = GritExt.encode!("yummy\xE2 \xF0\x9F\x8D\x94 \x9F\x8D\x94")
    assert_equal message, "yummy 🍔 "
    assert_equal message.encoding.name, "UTF-8"
  end

  def test_encode_string
    message = GritExt.encode!("{foo \xC3 'bar'}")
    assert_equal message, "{foo Ã 'bar'}"
    assert_equal message.encoding.name, "UTF-8"

    message = "我爱你".encode("GBK")
    assert_equal message.encoding.name, "GBK"

    GritExt.encode!(message)
    assert_equal message, "我爱你"
    assert_equal message.encoding.name, "UTF-8"
  end
end

