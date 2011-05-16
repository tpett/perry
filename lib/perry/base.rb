# TRP: Perry modules
require 'perry/errors'
require 'perry/associations/contains'
require 'perry/associations/external'
require 'perry/serialization'
require 'perry/relation'
require 'perry/scopes'
require 'perry/adapters'
require 'perry/middlewares'
require 'perry/processors'

class Perry::Base
  include Perry::Associations::Contains
  include Perry::Associations::External
  include Perry::Serialization
  include Perry::Scopes

  DEFAULT_PRIMARY_KEY = :id

  attr_accessor :attributes, :new_record, :saved, :read_options, :write_options
  alias :new_record? :new_record
  alias :saved? :saved
  alias :persisted? :saved?

  class_inheritable_accessor :read_adapter, :write_adapter,
    :defined_attributes, :scoped_methods, :defined_associations

  self.defined_associations = {}
  self.defined_attributes = []

  def initialize(attributes={})
    self.new_record = true
    set_attributes(attributes)
  end

  def [](attribute)
    @attributes[attribute.to_s]
  end

  def errors
    @errors ||= {}
  end

  def primary_key
    self.class.primary_key
  end

  protected

  # TRP: Common interface for setting attributes to keep things consistent; if
  # force is true the defined_attributes list will be ignored
  def set_attributes(attributes, force=false)
    attributes = attributes.inject({}) do |options, (key, value)|
      options[key.to_s] = value
      options
    end
    @attributes = {} if @attributes.nil?
    @attributes.merge!(attributes.reject { |field, value|
      !self.defined_attributes.include?(field) && !force
    })
  end

  def set_attribute(attribute, value, force=false)
    set_attributes({ attribute => value }, force)
  end

  # Class Methods
  class << self
    public

    delegate :find, :first, :all, :search, :apply_finder_options, :to => :scoped
    delegate :select, :group, :order, :joins, :where, :having, :limit, :offset,
      :from, :includes, :to => :scoped
    delegate :modifiers, :to => :scoped

    def primary_key
      @primary_key || DEFAULT_PRIMARY_KEY
    end

    # Allows you to specify an attribute other than :id to use as your models
    # primary key.
    #
    def set_primary_key(attribute)
      unless defined_attributes.include?(attribute.to_s)
        raise Perry::PerryError.new("cannot set primary key to non-existent attribute")
      end
      @primary_key = attribute.to_sym
    end

    def new_from_data_store(hash)
      if hash.nil?
        nil
      else
        record = self.new(hash)
        record.new_record = false
        record
      end
    end

    def unscoped
      current_scopes = self.scoped_methods
      self.scoped_methods = []
      begin
        yield
      ensure
        self.scoped_methods = current_scopes
      end
    end

    def inherited(subclass)
      update_extension_map(self, subclass)
      super
    end

    def respond_to?(method, include_private=false)
      super ||
      scoped.dynamic_finder_method(method)
    end

    protected

    def fetch_records(relation)
      self.read_adapter.call(:read, :relation => relation).compact
    end

    def read_with(adapter_type)
      setup_adapter(:read, { :type => adapter_type })
    end

    def write_with(adapter_type)
      if write_adapter
        write_inheritable_attribute :write_adapter, nil if adapter_type != write_adapter.type
      else
        # TRP: Pull in methods and libraries needed for mutable functionality
        require 'perry/persistence' unless defined?(Perry::Persistence)
        self.send(:include, Perry::Persistence) unless self.class.ancestors.include?(Perry::Persistence)

        # TRP: Create writers if attributes are declared before configure_mutable is called
        self.defined_attributes.each { |attribute| create_writer(attribute) }
        # TRP: Create serialized writers if attributes are declared serialized before this call
        self.serialized_attributes.each { |attribute| set_serialize_writers(attribute) }
      end
      setup_adapter(:write, { :type => adapter_type })
    end

    def configure_read(&block)
      configure_adapter(:read, &block)
    end

    def configure_write(&block)
      configure_adapter(:write, &block)
    end

    def method_missing(method, *args, &block)
      if scoped.dynamic_finder_method(method)
        scoped.send(method, *args, &block)
      else
        super
      end
    end

    # TRP: Used to declare attributes -- only attributes that are declared will be available
    def attributes(*attributes)
      return self.defined_attributes if attributes.empty?

      [*attributes].each do |attribute|
        self.defined_attributes << attribute.to_s

        define_method(attribute) do
          self[attribute]
        end

        # TRP: Setup the writers if mutable is set
        create_writer(attribute) if self.write_adapter

      end
    end
    def attribute(*attrs)
      self.attributes(*attrs)
    end

    def relation
      @relation ||= Perry::Relation.new(self)
    end

    def default_scope(scope)
      base_scope = current_scope || relation
      self.scoped_methods << (scope.is_a?(Hash) ? base_scope.apply_finder_options(scope) : base_scope.merge(scope))
    end

    def current_scope
      self.scoped_methods ||= []
      self.scoped_methods.last
    end

    private

    def setup_adapter(mode, config)
      current_adapter = read_inheritable_attribute :"#{mode}_adapter"
      type = config[:type] if config.is_a?(Hash)

      new_adapter = if type == :none
        nil
      elsif current_adapter
        current_adapter.extend_adapter(config)
      else
        Perry::Adapters::AbstractAdapter.create(type, config)
      end

      write_inheritable_attribute :"#{mode}_adapter", new_adapter
    end

    def configure_adapter(mode, &block)
      raise ArgumentError, "A block must be passed to configure_#{mode} method." unless block_given?
      raise ArgumentError, "You must first define an adapter before configuring it.  Use #{mode}_with :adapter_type." unless self.send(:"#{mode}_adapter")

      setup_adapter(mode, block)
    end

  end

end
