class String
  if ((defined? RUBY_VERSION) && (['1.9', '2.0'].include? RUBY_VERSION[0..2]))
    def getord(offset); self[offset].ord; end
  else
    alias :getord :[]
  end
end
