module RPCMapper::Associations

  module Common
    module ClassMethods

      protected

      def extension_map
        @@extension_map ||= Hash.new(Array.new)
      end

      def update_extension_map(old_klass, new_klass)
        self.extension_map[old_klass] += [new_klass] if base_class_name(old_klass) == base_class_name(new_klass)
      end

      # TRP: This will return the most recent extension of klass or klass if it is a leaf node in the hierarchy
      def resolve_leaf_klass(klass)
        extension_map[klass].empty? ? klass : resolve_leaf_klass(extension_map[klass].last)
      end

      def base_class_name(klass)
        klass.to_s.split("::").last
      end

    end

    module InstanceMethods

      protected

      def klass_from_association_options(association, options)
        klass = if options[:polymorphic]
          eval [options[:polymorphic_namespace], self.send("#{association}_type")].compact.join('::')
        else
          raise(ArgumentError, ":class_name or :klass option required for association declaration.") unless options[:class_name] || options[:klass]
          options[:class_name] = "::#{options[:class_name]}" unless options[:class_name] =~ /^::/
          options[:klass] || eval(options[:class_name])
        end

        self.class.send :resolve_leaf_klass, klass
      end

    end

    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end

end