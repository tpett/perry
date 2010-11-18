module RPCMapper::AssociationPreload
  module ClassMethods

    def eager_load_associations(original_results, relation)
      relation.includes_values.each do |association_id|
        association = self.defined_associations[association_id.to_sym]
        options = association.options

        case association.type
        when :has_many
          fks = original_results.collect { |record| record.send(association.primary_key) }.compact

          records = association.target_klass.where(association.foreign_key => fks)

          original_results.each do |record|
            fk = record.send(association.primary_key)
            relevant_records = records.select { |r| r.send(association.foreign_key) == fk }
            relevant_records = association.collection? ? relevant_records : relevant_records.first
            record.send("#{association.id}=", relevant_records)
          end

        when :has_one
        when :belongs_to
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