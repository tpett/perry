module RPCMapper::Association; end

module RPCMapper::Association

  class Base
    attr_accessor :source_klass, :id, :options

    def initialize(klass, id, options={})
      self.source_klass = klass
      self.id = id.to_sym
      self.options = options
    end

    def type
      raise NotImplementedError, "You must define the type in subclasses."
    end

    def polymorphic?
      raise NotImplementedError, "You must define how your association is polymorphic in subclasses."
    end

    def collection?
      raise NotImplementedError, "You must define collection? in subclasses."
    end

    def primary_key
      options[:primary_key] || :id
    end

    def foreign_key
      options[:foreign_key]
    end

    def target_klass(object)
      klass = if options[:polymorphic]
        eval [options[:polymorphic_namespace], object.send("#{id}_type")].compact.join('::')
      else
        raise(ArgumentError, ":class_name or :klass option required for association declaration.") unless options[:class_name] || options[:klass]
        options[:class_name] = "::#{options[:class_name]}" unless options[:class_name] =~ /^::/
        options[:klass] || eval(options[:class_name])
      end

      RPCMapper::Base.resolve_leaf_klass klass
    end

    # TRP: Only eager loadable if association query does not depend on instance data
    def eager_loadable?
      !(options[:sql] || RPCMapper::Relation::FINDER_OPTIONS.inject(false) { |condition, key| condition || options[key].respond_to?(:call) })
    end

    protected

    def build_finder_options(object)
      RPCMapper::Relation::FINDER_OPTIONS.inject({}) do |sum, key|
        value = self.options[key]
        sum.merge!(:sql => object.send(:instance_eval, "%@#{value.gsub('@', '\@')}@", __FILE__, __LINE__)) if key == :sql && value
        sum.merge!(key => value.respond_to?(:call) ? value.call(object) : value) if value
        sum
      end
    end

  end


  class BelongsTo < Base

    def type
      :belongs_to
    end

    def collection?
      false
    end

    def foreign_key
      super || "#{id}_id".to_sym
    end

    def polymorphic?
      !!options[:polymorphic]
    end

    def scope(object)
      target_klass(object).scoped.apply_finder_options build_finder_options(object).deep_merge({ :conditions => (object[self.foreign_key] ? { self.primary_key => object[self.foreign_key] } : nil) })
    end

  end


  class Has < Base

    def foreign_key
      super || (self.polymorphic? ? "#{options[:as]}_id" : "#{source_klass.name.split('::').last.downcase}_id").to_sym
    end

    def scope(object)
      query_options = if object[self.primary_key]
        conditions = { self.foreign_key => object[self.primary_key] }
        conditions.merge!(:"#{options[:as]}_type" => RPCMapper::Base.base_class_name(object.class)) if polymorphic?
        { :conditions => conditions }
      else
        {}
      end

      target_klass(object).scoped.apply_finder_options build_finder_options(object).deep_merge(query_options)
    end

    def polymorphic?
      !!options[:as]
    end

  end


  class HasMany < Has

    def collection?
      true
    end

    def type
      :has_many
    end

  end


  class HasOne < Has

    def collection?
      false
    end

    def type
      :has_one
    end

  end


end
