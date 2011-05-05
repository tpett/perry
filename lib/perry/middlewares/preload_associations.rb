##
# Perry::Middlewares::PreloadAssociations
#
# This middleware will allow associations to be eager loaded after the original records are fetched.
# Any associations specified in an :includes option will be loaded for all records in the query
# (each association in a single request).
#
class Perry::Middlewares::PreloadAssociations

  def initialize(adapter, config={})
    @adapter = adapter
    @config = config
  end

  def call(options)
    @adapter.call(options)
  end

end

