module Perry::Cacheable

  class Store

    attr_reader :store
    attr_accessor :default_longevity

    # TRP: Specify the default longevity of a cache entry in seconds
    def initialize(default_longevity)
      @store = {}
      @default_longevity = default_longevity
    end

    def clear(key=nil)
      if key
        @store.delete(key)
      else
        @store.each do |key, entry|
          clear(key) if key && (!entry || entry.expired?)
        end
      end
    end

    # TRP: Returns value if a cache hit and the entry is not expired, nil otherwise
    def read(key)
      if entry = @store[key]
        if entry.expired?
          clear(key)
          nil
        else
          entry.value
        end
      end
    end

    # TRP: Write a new cache value and optionally specify the expire time
    #      this also will clear all expired items out of the store to keep memory consumption as low as possible
    def write(key, value, expires=Time.now + default_longevity)
      clear
      @store[key] = Entry.new(value, expires)
    end

  end

end
