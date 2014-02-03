module Grit
  module Encode
    ENCODING_MAP = {
      'koi8r' => 'KOI8-R',
    }

    def find_ruby_encoding(encoding)
      return nil  unless defined?(Encoding)
      Encoding.find(ENCODING_MAP[encoding] || encoding)
    rescue ArgumentError
      warn "Cannot map git encoding to ruby one: #{encoding}"
      nil
    end

   def message_in_utf8(message, encoding)
      message = message.dup
      message.force_encoding('UTF-8')  if message.respond_to?(:force_encoding)
      if encoding && encoding !~ /\Autf\-8i\z/i && message && message.respond_to?(:encode!)
        ruby_encoding = find_ruby_encoding(encoding)
        if ruby_encoding
          message.encode!('UTF-8', ruby_encoding, :invalid => :replace, :undef => :replace)
          unless message.valid_encoding?
            message.encode!('UTF-8', 'ISO-8859-1', :invalid => :replace, :undef => :replace)
          end
        else
          unless message.valid_encoding?
            message.encode!('UTF-8', 'ISO-8859-1', :invalid => :replace, :undef => :replace)
          end
        end
      end
      message
    end
  end
end

