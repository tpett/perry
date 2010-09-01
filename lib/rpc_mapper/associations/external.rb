require 'rpc_mapper/associations/common'

module RPCMapper::Associations

  module External
    module ClassMethods

      def belongs_to(association, options={})
        create_external_association(:belongs, association, options)
      end

      def has_one(association, options={})
        create_external_association(:one, association, options)
      end

      def has_many(association, options={})
        create_external_association(:many, association, options)
      end

      protected

      def create_external_association(association_type, association, association_options={})
        cache_ivar = "@association_#{association}"
        self.declared_associations[association] = [association_type, association_options]

        define_method(association) do
          type = self.class.declared_associations[association].first
          options = self.class.declared_associations[association].last.dup
          options = options.is_a?(Proc) ? options.call(self) : options
          klass = klass_from_association_options(association, options)
          cached_value = instance_variable_get(cache_ivar)

          options[:primary_key] = (options[:primary_key] || "id").to_sym
          options[:foreign_key] = (options[:foreign_key] || ((type == :belongs) ? "#{association}_id" : "#{self.class.name.split('::').last.downcase}_id")).to_sym

          # TRP: Logic for actually pulling setting the value
          unless cached_value
            query_options = build_query_options_for_external_association(type, options)
            cached_value = case type
            when :belongs, :one
              klass.first(query_options) if query_options[:conditions] # TRP: Only run query if conditions is not nil
            when :many
              klass.all(query_options)   if query_options[:conditions] # TRP: Only run query if conditions is not nil
            end
            instance_variable_set(cache_ivar, cached_value)
          end

          cached_value
        end

        # TRP: Allow eager loading of the association without having to load it through the normal accessor
        define_method("#{association}=") do |value|
          instance_variable_set(cache_ivar, value)
        end
      end

    end

    module InstanceMethods

      protected

      def build_query_options_for_external_association(type, options)
        as = options[:as]
        as_type = self.class.send(:base_class_name, self.class) if as

        pk = options[:primary_key].to_sym
        fk = (as ? "#{as}_id" : options[:foreign_key]).to_sym

        default_query_options = case type
        when :belongs
          { :conditions => (self[fk] ? { pk => self[fk] } : nil) } # TRP: Only add conditions if the fk is not nil
        when :one, :many
          # TRP: Only add conditions if the pk is not nil
          if self[pk]
            conditions = { fk => self[pk] }
            conditions.merge!(:"#{as}_type" => as_type) if as
            { :conditions => conditions }
          else
            {}
          end
        end

        configured_query_options = {}
        RPCMapper::Relation::FINDER_OPTIONS.each do |key|
          value = options[key]
          configured_query_options.merge!({ key => value.respond_to?(:call) ? value.call(self) : value }) if value
        end

        default_query_options.deep_merge(configured_query_options)
      end

    end

    def self.included(receiver)
      receiver.send :include, RPCMapper::Associations::Common
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end

end