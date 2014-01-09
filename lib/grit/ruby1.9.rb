class String
  if (defined? RUBY_VERSION) && RUBY_VERSION >= "1.9" then
    def getord(offset); self[offset].ord; end
  else
    alias :getord :[]
  end
end
