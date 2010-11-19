require 'rpc_mapper/associations/common'
require 'rpc_mapper/association'

module RPCMapper::Associations

  module External
    module ClassMethods

      def belongs_to(id, options={})
        create_external_association RPCMapper::Association::BelongsTo.new(self, id, options)
      end

      def has_one(id, options={})
        create_external_association RPCMapper::Association::HasOne.new(self, id, options)
      end

      def has_many(id, options={})
        create_external_association RPCMapper::Association::HasMany.new(self, id, options)
      end

      protected

      def create_external_association(association)
        cache_ivar = "@association_#{association.id}"
        self.defined_associations[association.id] = association

        define_method(association.id) do
          cached_value = instance_variable_get(cache_ivar)

          # TRP: Logic for actually pulling setting the value
          unless cached_value
            scoped = association.scope(self)

            cached_value = association.collection? ? scoped : scoped.first if scoped && !scoped.where_values.empty?

            instance_variable_set(cache_ivar, cached_value)
          end

          cached_value
        end

        # TRP: Allow eager loading of the association without having to load it through the normal accessor
        define_method("#{association.id}=") do |value|
          instance_variable_set(cache_ivar, value)
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