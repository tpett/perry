##
# = Perry::Processors::PreloadAssociations
#
# This adapter processor will allow associations to be eager loaded after the original records are fetched.
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
class Perry::Processors::PreloadAssociations

  def initialize(adapter, config={})
    @adapter = adapter
    @config = config
  end

  def call(options)
    results = @adapter.call(options)

    unless results.empty?
      relation = options[:relation]
      (includes = relation.to_hash[:includes] || {}).keys.each do |association_id|
        association = relation.klass.defined_associations[association_id.to_sym]
        raise Perry::AssociationNotFound, "unknown association #{association_id}" unless association
        eager_records = association.scope(results).includes(includes[association_id]).all(:modifiers => options[:relation].modifiers_value)

        results.each do |result|
          scope = association.scope(result)
          case association.type
          when :has_one, :has_many
            scope.records = eager_records.select do |record|
              record.send(association.foreign_key) == result.send(association.primary_key)
            end
            if association.collection?
              result.send("#{association.id}=", scope)
            else
              result.send("#{association.id}=", scope.records.first)
            end
          when :belongs_to
            scope.records = eager_records.select do |record|
              record.send(association.primary_key) == result.send(association.foreign_key)
            end
            result.send("#{association.id}=", scope.records.first)
          end
        end
      end
    end

    results
  end

end

