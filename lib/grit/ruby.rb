class String
  if ((defined? RUBY_VERSION) && (RUBY_VERSION[0..2].to_f >= 1.9))
    def getord(offset); self[offset].ord; end
  else
    alias :getord :[]
  end
end