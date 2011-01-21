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
      klass = if options[:polymorphic] && object
        type_string = [
          options[:polymorphic_namespace],
          sanitize_type_attribute(object.send("#{id}_type"))
        ].compact.join('::')
        begin
          eval(type_string)
        rescue NameError => err
          raise(
            RPCMapper::PolymorphicAssociationTypeError,
            "No constant defined called #{type_string}"
          )
        end
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

    # TRP: Make sure the value looks like a variable syntaxtually
    def sanitize_type_attribute(string)
      string.gsub(/[^a-zA-Z]\w*/, '')
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


    ##
    # Returns a scope on the target containing this association
    #
    # Builds conditions on top of the base_scope generated from any finder options set with the association
    #
    #   has_many :widgets, :class_name => "Widget", :foreign_key => :widget_id
    #   has_many :comments, :as => :parent
    #
    # In addition to any finder options included with the association options the following will be added:
    #
    #   where(widget_id => source[:id])
    #
    # Or for the polymorphic :comments association:
    #
    #   where(:parent_id => source[:id], :parent_type => source.class)
    #
    def scope(object)
      s = base_scope(object).where(self.foreign_key => object[self.primary_key]) if object[self.primary_key]
      s = s.where(polymorphic_type => RPCMapper::Base.base_class_name(object.class)) if s && polymorphic?
      s
    end

    def polymorphic_type
      :"#{options[:as]}_type"
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


  class HasManyThrough < HasMany
    attr_accessor :proxy_association
    attr_accessor :source_association

    def proxy_association
      @proxy_association ||= source_klass.defined_associations[options[:through]] ||
        raise(
          RPCMapper::AssociationNotFound,
          ":has_many_through: '#{options[:through]}' is not an association on #{source_klass}"
        )
    end

    def source_association
      return @source_association if @source_association

      klass = proxy_association.target_klass
      @source_association = klass.defined_associations[self.id] ||
        klass.defined_associations[self.options[:source]] ||
        raise(
          RPCMapper::AssociationNotFound,
          ":has_many_through: '#{options[:source] || self.id}' is not an association on #{klass}"
        )
    end

    def scope(object)
      proxy_ids = proxy_association.scope(object).select(:id).collect(&:id)
      relation = source_association.target_klass.scoped
      relation = relation.where(source_association.foreign_key => proxy_ids)
      if source_association.polymorphic?
        relation = relation.where(source_association.polymorphic_type => RPCMapper::Base.base_class_name(proxy_association.target_klass))
      end
      relation
    end

    def target_klass
      source_association.target_klass
    end

    def type
      :has_many_through
    end

    def polymorphic?
      false
    end

  end


end
