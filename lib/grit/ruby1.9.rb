class String
  if self.method_defined?(:ord)
    def getord(offset); self[offset].ord; end
  else
    alias :getord :[]
  end
end
