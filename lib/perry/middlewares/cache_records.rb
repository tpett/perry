class Perry::Middlewares::CacheRecords; end
require 'perry/middlewares/cache_records/store'
require 'perry/middlewares/cache_records/entry'
require 'perry/middlewares/cache_records/scopes'
require 'digest/md5'

class Perry::Middlewares::CacheRecords
  attr_accessor :record_count_threshold

  # TRP: Default to a 5 minute cache
  DEFAULT_LONGEVITY = 5*60
  @@cache_store = nil

  def reset_cache_store(default_longevity=DEFAULT_LONGEVITY)
    @@cache_store = Perry::Middlewares::CacheRecords::Store.new(default_longevity)
  end

  def cache_store
    @@cache_store || reset_cache_store
  end

  def initialize(adapter, config={})
    @adapter = adapter
    self.record_count_threshold = config[:record_count_threshold]
  end

  def call(options)
    relation = options[:relation]
    modifiers = relation.modifiers_value
    query = relation.to_hash

    reset_cache_store if modifiers[:reset_cache]
    get_fresh = modifiers[:fresh]

    key = key_for_query(query)
    cached_values = self.cache_store.read(key)


    if cached_values && !get_fresh
      @adapter.log(query, "CACHE #{relation.klass.name}")
      cached_values
    else
      fresh_values = @adapter.call(options)
      if self.record_count_threshold && fresh_values.size <= self.record_count_threshold
        self.cache_store.write(key, fresh_values)
      end
      fresh_values
    end
  end

  def key_for_query(query_hash)
    Digest::MD5.hexdigest(self.class.to_s + query_hash.to_a.sort { |a,b| a.to_s.first <=> b.to_s.first }.inspect)
  end
end
