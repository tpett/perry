require 'rpc_mapper/associations/common'

module RPCMapper::Associations

  module Contains
    module ClassMethods

      # TRP: Define an association that is serialized within the data for this class.
      # If a subset of the data returned for a class contains the data for another class you can use the contains_many
      # association to (lazy) auto initialize the specified object(s) using the data from that attribute.
      def contains_many(association, options={})
        create_contains_association(:many, association, options)
      end

      # TRP: Same as contains_many, but only works with a single record
      def contains_one(association, options={})
        create_contains_association(:one, association, options)
      end

      private

      def create_contains_association(type, association, options)
        attribute = (options[:attribute] || association).to_sym
        cache_variable = "@association_#{association}"

        self.defined_attributes << association.to_s unless self.defined_attributes.include?(association.to_s)
        define_method(association) do
          klass = klass_from_association_options(association, options)
          records = instance_variable_get(cache_variable)

          unless records
            records = case type
            when :many
              self[attribute].collect { |record| klass.new_from_data_store(record) } if self[attribute]
            when :one
              klass.new_from_data_store(self[attribute]) if self[attribute]
            end
            instance_variable_set(cache_variable, records)
          end

          records
        end

        # TRP: This method will allow eager loaded values to be loaded into the association
        define_method("#{association}=") do |value|
          instance_variable_set(cache_variable, value)
        end

      end

    end

    module InstanceMethods

    end

    def self.included(receiver)
      receiver.send :include, RPCMapper::Associations::Common
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end

end
