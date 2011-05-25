class Perry::Middlewares::CacheRecords; end
require 'perry/middlewares/cache_records/store'
require 'perry/middlewares/cache_records/entry'
require 'perry/middlewares/cache_records/scopes'
require 'digest/md5'

class Perry::Middlewares::CacheRecords
  include Perry::Logger

  attr_accessor :record_count_threshold

  # TRP: Default to a 5 minute cache
  DEFAULT_LONGEVITY = 5*60

  def self.global_cache
    @@global_cache ||= {}
  end

  def self.reset_global_cache
    @@global_cache = {}
  end

  def reset_cache_store(default_longevity=DEFAULT_LONGEVITY)
    self.class.global_cache[self] = Perry::Middlewares::CacheRecords::Store.new(default_longevity)
  end

  def cache_store
    self.class.global_cache[self] || reset_cache_store
  end

  def initialize(adapter, config={})
    @adapter = adapter
    self.record_count_threshold = config[:record_count_threshold]
  end

  def call(options)
    if options[:relation] && Perry::Caching.enabled?
      call_with_cache(options)
    else
      @adapter.call(options)
    end
  end

  protected

  def call_with_cache(options)
    relation = options[:relation]
    modifiers = relation.modifiers_value
    query = relation.to_hash

    reset_cache_store if modifiers[:reset_cache]
    get_fresh = modifiers[:fresh]

    key = key_for_query(query)
    cached_values = self.cache_store.read(key)


    if cached_values && !get_fresh
      log(query, "CACHE #{relation.klass.name}")
      cached_values
    else
      fresh_values = @adapter.call(options)
      self.cache_store.write(key, fresh_values) if should_store_in_cache?(fresh_values, options)
      fresh_values
    end
  end

  def key_for_query(query_hash)
    Digest::MD5.hexdigest(self.class.to_s + query_hash.to_a.sort { |a,b| a.to_s.first <=> b.to_s.first }.inspect)
  end

  def should_store_in_cache?(fresh_values, options)
    fresh_values &&
    (!self.record_count_threshold || fresh_values.size <= self.record_count_threshold) &&
    !options[:noop]
  end
end

# Register the cache clearing method with the Caching class
Perry::Caching.register(Perry::Middlewares::CacheRecords.method(:reset_global_cache))

