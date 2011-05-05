class Perry::Middlewares::CacheRecords
  def initialize(adapter, config={})
    @adapter = adapter
  end

  def call(options)
    @adapter.call(options)
  end
end
