module RPCMapper::Association; end

module RPCMapper::Association

  ##
  # Association::Base
  #
  # This is the base class for all associations.  It defines the basic structure
  # of an association.  The basic nomenclature is as follows:
  #
  # Source:  The start point of the association.  The source class is the class
  # on which the association is defined.
  #
  # Proxy:  On a through association the proxy is the class on which the target
  # association lives
  #
  # Target:  The class that will ultimately be returned by the association
  #
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
      raise(
        NotImplementedError,
        "You must define how your association is polymorphic in subclasses."
      )
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
      if options[:polymorphic] && object
        poly_type = object.is_a?(RPCMapper::Base) ? object.send("#{id}_type") : object
      end

      klass = if poly_type
        type_string = [
          options[:polymorphic_namespace],
          sanitize_type_attribute(poly_type)
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
        unless options[:class_name]
          raise(ArgumentError,
                ":class_name option required for association declaration.")
        end

        unless options[:class_name] =~ /^::/
          options[:class_name] = "::#{options[:class_name]}"
        end

        eval(options[:class_name])
      end

      RPCMapper::Base.resolve_leaf_klass klass
    end

    def scope(object)
      raise NotImplementedError, "You must define scope in subclasses"
    end

    # TRP: Only eager loadable if association query does not depend on instance
    # data
    def eager_loadable?
      RPCMapper::Relation::FINDER_OPTIONS.inject(true) do |condition, key|
        condition && !options[key].respond_to?(:call)
      end
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

    def polymorphic_type
      "#{id}_type".to_sym
    end

    ##
    # Returns a scope on the target containing this association
    #
    # Builds conditions on top of the base_scope generated from any finder
    # options set with the association
    #
    # belongs_to :foo, :foreign_key => :foo_id
    #
    # In addition to any finder options included with the association options
    # the following scope will be added:
    #  where(:id => source[:foo_id])
    #
    def scope(object)
      if object[self.foreign_key]
        base_scope(object).where(self.primary_key => object[self.foreign_key])
      end
    end

  end


  class Has < Base

    def foreign_key
      super || if self.polymorphic?
        "#{options[:as]}_id"
      else
         "#{RPCMapper::Base.base_class_name(source_klass).downcase}_id"
      end.to_sym
    end


    ##
    # Returns a scope on the target containing this association
    #
    # Builds conditions on top of the base_scope generated from any finder
    # options set with the association
    #
    #   has_many :widgets, :class_name => "Widget", :foreign_key => :widget_id
    #   has_many :comments, :as => :parent
    #
    # In addition to any finder options included with the association options
    # the following will be added:
    #
    #   where(widget_id => source[:id])
    #
    # Or for the polymorphic :comments association:
    #
    #   where(:parent_id => source[:id], :parent_type => source.class)
    #
    def scope(object)
      return nil unless object[self.primary_key]
      s = base_scope(object).where(self.foreign_key => object[self.primary_key])
      if polymorphic?
        s = s.where(
          polymorphic_type => RPCMapper::Base.base_class_name(object.class) )
      end
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
    attr_accessor :target_association

    def proxy_association
      @proxy_association ||= source_klass.defined_associations[options[:through]] ||
        raise(
          RPCMapper::AssociationNotFound,
          ":has_many_through: '#{options[:through]}' is not an association " +
          "on #{source_klass}"
        )
    end

    def target_association
      return @target_association if @target_association

      klass = proxy_association.target_klass
      @target_association = klass.defined_associations[self.id] ||
        klass.defined_associations[self.options[:source]] ||
        raise(RPCMapper::AssociationNotFound,
          ":has_many_through: '#{options[:source] || self.id}' is not an " +
          "association on #{klass}"
        )
    end

    def scope(object)
      key = if target_association.is_a?(Has)
        target_association.primary_key.to_sym
      else
        target_association.foreign_key.to_sym
      end

      # Fetch the ids of all records on the proxy
      proxy_ids = proxy_association.scope(object).select(key).collect(&key)

      # Use these ids to build a scope on the target object
      relation = target_association.target_klass(options[:source_type]).scoped
      if target_association.is_a?(Has)
        relation = relation.where(target_association.foreign_key => proxy_ids)
      else
        relation = relation.where(target_association.primary_key => proxy_ids)
      end

      # Add polymorphic type condition if target is polymorphic
      # TODO: Does this work for both belongs and has polymorphic targets?
      if target_association.polymorphic?
        relation = relation.where(
          target_association.polymorphic_type =>
            RPCMapper::Base.base_class_name(proxy_association.target_klass(object))
        )
      end

      relation
    end

    def target_klass
      target_association.target_klass
    end

    def type
      :has_many_through
    end

    def polymorphic?
      false
    end

  end


end
