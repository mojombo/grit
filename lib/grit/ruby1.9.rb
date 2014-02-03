class String
  if ((defined? RUBY_VERSION) && (RUBY_VERSION[0..2] == "1.9" || RUBY_VERSION.split('.').first.to_i > 1))
    def getord(offset); self[offset].ord; end
  else
    alias :getord :[]
  end
end
