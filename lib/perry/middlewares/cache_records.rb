class Perry::Middlewares::CacheRecords; end
require 'perry/middlewares/cache_records/store'
require 'perry/middlewares/cache_records/entry'

class Perry::Middlewares::CacheRecords
  def initialize(adapter, config={})
    @adapter = adapter
  end

  def call(options)
    @adapter.call(options)
  end
end
