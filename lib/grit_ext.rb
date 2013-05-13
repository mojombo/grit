require "charlock_holmes"
require "grit_ext/actor"
require "grit_ext/blob"
require "grit_ext/commit"
require "grit_ext/tree"
require "grit_ext/diff"
require "grit_ext/version"

module GritExt
  extend self

  def encode!(message)
    return nil unless message.respond_to? :force_encoding

    # if message is utf-8 encoding, just return it
    message.force_encoding("UTF-8")
    return message if message.valid_encoding?

    # return message if message type is binary
    detect = CharlockHolmes::EncodingDetector.detect(message)
    return message.force_encoding("BINARY") if detect && detect[:type] == :binary

    # encoding message to detect encoding
    if detect && detect[:encoding]
      message.force_encoding(detect[:encoding])
    end

    # encode and clean the bad chars
    message.replace clean(message)
  rescue
    encoding = detect ? detect[:encoding] : "unknown"
    "--broken encoding: #{encoding}"
  end

  private
  def clean(message)
    message.encode("UTF-16BE", :undef => :replace, :invalid => :replace, :replace => "")
           .encode("UTF-8")
           .gsub("\0".encode("UTF-8"), "")
  end
end
