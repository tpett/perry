##
# = Perry::Middlewares::PreloadAssociations
#
# This middleware will allow associations to be eager loaded after the original records are fetched.
# Any associations specified in an :includes option will be loaded for all records in the query
# (each association in a single request).
#
# == Configuration Options:
#
# None
#
# == Modifiers:
#
# None
#
#
#
class Perry::Middlewares::PreloadAssociations

  def initialize(adapter, config={})
    @adapter = adapter
    @config = config
  end

  def call(options)
    relation = options[:relation]
    (relation.to_hash[:includes] || []).each do |association_id|
      result = fetch_association(relation.klass.defined_associations[association_id.to_sym], options)
    end
    @adapter.call(options)
  end

  protected

  def fetch_association(association, options)
    association.target_klass.first
  end

end

