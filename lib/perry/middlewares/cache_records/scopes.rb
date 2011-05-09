module Perry::Middlewares::CacheRecords::Scopes
  def self.included(model)
    model.class_eval do

      # Using the :fresh scope will skip the cache and execute query regardless of
      # whether a cached result is available or not.
      scope :fresh, modifiers(:fresh => true)

      # Using the :reset_cache scope in a query will delete all entries from the
      # cache store before running the query. Whenever possible, you should use
      # the :fresh scope instead of :reset_cache.
      scope :reset_cache, modifiers(:reset_cache => true)
    end
  end
end
