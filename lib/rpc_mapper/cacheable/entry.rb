module RPCMapper::Cacheable
  
  class Entry
    
    attr_accessor :value, :expire_at
    
    def initialize(value, expire_at)
      self.value = value
      self.expire_at = expire_at
    end
    
    def expired?
      Time.now > self.expire_at rescue true
    end
    
  end
  
end
