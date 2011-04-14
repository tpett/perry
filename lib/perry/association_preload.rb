module Perry::AssociationPreload
  module ClassMethods

    def eager_load_associations(original_results, relation)
      relation.includes_values.each do |association_id|
        association = self.defined_associations[association_id.to_sym]
        force_fresh = relation.fresh_value

        unless association
          raise(
            Perry::AssociationNotFound,
            "no such association (#{association_id})"
          )
        end

        unless association.eager_loadable?
          raise(
            Perry::AssociationPreloadNotSupported,
            "delayed execution options (block options) cannot be used for eager loaded associations"
          )
        end

        options = association.options

        case association.type
        when :has_many, :has_one
          fks = original_results.collect { |record| record.send(association.primary_key) }.compact

          pre_records = association.target_klass.where(association.foreign_key => fks).all(:fresh => force_fresh)

          original_results.each do |record|
            pk = record.send(association.primary_key)
            relevant_records = pre_records.select { |r| r.send(association.foreign_key) == pk }

            relevant_records = if association.collection?
              scope = association.scope(record).where(association.foreign_key => pk)
              scope.records = relevant_records
              scope
            else
              relevant_records.first
            end

            record.send("#{association.id}=", relevant_records)
          end

        when :belongs_to
          fks = original_results.collect { |record| record.send(association.foreign_key) }.compact

          pre_records = association.target_klass.where(association.primary_key => fks).all(:fresh => force_fresh)

          original_results.each do |record|
            fk = record.send(association.foreign_key)
            relevant_records = pre_records.select { |r| r.send(association.primary_key) == fk }.first
            record.send("#{association.id}=", relevant_records)
          end
        end
      end
    end

  end

  module InstanceMethods
  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
end
