# TRP: RPCMapper modules
require 'rpc_mapper/errors'
require 'rpc_mapper/associations/contains'
require 'rpc_mapper/associations/external'
require 'rpc_mapper/association_preload'
require 'rpc_mapper/cacheable'
require 'rpc_mapper/serialization'
require 'rpc_mapper/relation'
require 'rpc_mapper/scopes'
require 'rpc_mapper/adapters'


class RPCMapper::Base
  include RPCMapper::Associations::Contains
  include RPCMapper::Associations::External
  include RPCMapper::AssociationPreload
  include RPCMapper::Serialization
  include RPCMapper::Scopes

  attr_accessor :attributes, :new_record, :read_options, :write_options
  alias :new_record? :new_record

  class_inheritable_accessor :read_adapter, :write_adapter, :cacheable, :defined_attributes, :scoped_methods, :defined_associations

  self.cacheable = false
  self.defined_associations = {}
  self.defined_attributes = []

  def initialize(attributes={})
    self.new_record = true
    set_attributes(attributes)
  end

  def [](attribute)
    @attributes[attribute.to_s]
  end

  protected

  # TRP: Common interface for setting attributes to keep things consistent; if force is true the defined_attributes list will be ignored
  def set_attributes(attributes, force=false)
    attributes = attributes.inject({}) do |options, (key, value)|
      options[key.to_s] = value
      options
    end
    @attributes = {} if @attributes.nil?
    @attributes.merge!(attributes.reject { |field, value| !self.defined_attributes.include?(field) && !force })
  end

  def set_attribute(attribute, value, force=false)
    set_attributes({ attribute => value }, force)
  end

  # Class Methods
  class << self
    public

    delegate :find, :first, :all, :search, :apply_finder_options, :to => :scoped
    delegate :select, :group, :order, :joins, :where, :having, :limit, :offset, :from, :fresh, :to => :scoped

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
      options = relation.to_hash
      self.read_adapter.read(options).collect { |hash| self.new_from_data_store(hash) }.compact.tap { |result| eager_load_associations(result, relation) }
    end

    def read_with(adapter_type)
      setup_adapter(:read, { :type => adapter_type })
    end

    def write_with(adapter_type)
      if write_adapter
        write_inheritable_attribute :write_adapter, nil if adapter_type != write_adapter.type
      else
        # TRP: Pull in methods and libraries needed for mutable functionality
        require 'rpc_mapper/persistence' unless defined?(RPCMapper::Persistence)
        self.send(:include, RPCMapper::Persistence) unless self.class.ancestors.include?(RPCMapper::Persistence)

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

    def configure_cacheable(options={})
      unless cacheable
        self.send(:include, RPCMapper::Cacheable)
        self.enable_caching(options)
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
      @relation ||= RPCMapper::Relation.new(self)
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

      new_adapter = if current_adapter
        current_adapter.extend_adapter(config)
      else
        RPCMapper::Adapters::AbstractAdapter.create(type, config)
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
