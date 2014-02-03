class String
  if ((defined? RUBY_VERSION) && (RUBY_VERSION[0..2] >= "1.9"))
    def getord(offset); self[offset].ord; end
  else
    alias :getord :[]
  end

  unless self.method_defined?(:b)
    if self.method_defined?(:force_encoding)
      def b; self.dup.force_encoding(Encoding::ASCII_8BIT); end
    else
      def b; self.dup; end
    end
  end

end
