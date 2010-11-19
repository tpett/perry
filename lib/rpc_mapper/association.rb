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

    def target_klass(object=nil)
      klass = if options[:polymorphic]
        eval [options[:polymorphic_namespace], object.send("#{id}_type")].compact.join('::') if object
      else
        raise(ArgumentError, ":class_name option required for association declaration.") unless options[:class_name]
        options[:class_name] = "::#{options[:class_name]}" unless options[:class_name] =~ /^::/
        eval(options[:class_name])
      end

      RPCMapper::Base.resolve_leaf_klass klass
    end

    def scope(object)
      raise NotImplementedError, "You must define scope in subclasses"
    end

    # TRP: Only eager loadable if association query does not depend on instance data
    def eager_loadable?
      RPCMapper::Relation::FINDER_OPTIONS.inject(true) { |condition, key| condition && !options[key].respond_to?(:call) }
    end

    protected

    def base_scope(object)
      target_klass(object).scoped.apply_finder_options base_finder_options(object)
    end

    def base_finder_options(object)
      RPCMapper::Relation::FINDER_OPTIONS.inject({}) do |sum, key|
        value = self.options[key]
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

    # Returns a scope on the target containing this association
    #
    # Builds conditions on top of the base_scope generated from any finder options set with the association
    #
    # belongs_to :foo, :foreign_key => :foo_id
    #
    # In addition to any finder options included with the association options the following scope will be added:
    #  where(:id => source[:foo_id])
    def scope(object)
      base_scope(object).where(self.primary_key => object[self.foreign_key]) if object[self.foreign_key]
    end

  end


  class Has < Base

    def foreign_key
      super || (self.polymorphic? ? "#{options[:as]}_id" : "#{RPCMapper::Base.base_class_name(source_klass).downcase}_id").to_sym
    end


    # Returns a scope on the target containing this association
    #
    # Builds conditions on top of the base_scope generated from any finder options set with the association
    #
    # has_many :widgets, :class_name => "Widget", :foreign_key => :widget_id
    # has_many :comments, :as => :parent
    #
    # In addition to any finder options included with the association options the following will be added:
    #  where(widget_id => source[:id])
    # Or for the polymorphic :comments association:
    #  where(:parent_id => source[:id], :parent_type => source.class)
    def scope(object)
      s = base_scope(object).where(self.foreign_key => object[self.primary_key]) if object[self.primary_key]
      s = s.where(:"#{options[:as]}_type" => RPCMapper::Base.base_class_name(object.class)) if s && polymorphic?
      s
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
