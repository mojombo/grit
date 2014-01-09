class String
  def getord(offset); self[offset].ord; end
end

class Integer
  # Probably oboselete. Ruby<1.8.7 needs this.
  method_defined? :ord or def ord ; self ; end
end
