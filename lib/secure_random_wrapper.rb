class SecureRandomWrapper
  def self.hex(n = nil)
    SecureRandom.hex(n)
  end
end
