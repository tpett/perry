# TRP: Cherry pick some goodies from active_support
require 'active_support/core_ext/array'
begin
  require 'active_support/core_ext/duplicable' #ActiveSupport 2.3.5
rescue LoadError => exception
  require 'active_support/core_ext/object/duplicable' #ActiveSupport 3.0.0.RC
end
require 'active_support/core_ext/class/inheritable_attributes'
require 'active_support/core_ext/hash/deep_merge'
require 'active_support/core_ext/module/delegation'
Hash.send(:include, ActiveSupport::CoreExtensions::Hash::DeepMerge) unless Hash.new.respond_to?(:deep_merge)

# TRP: Used for pretty logging
require 'benchmark'

# TRP: RPCMapper core_ext
require 'rpc_mapper/core_ext/kernel/singleton_class'

# TRP: RPCMapper modules
require 'rpc_mapper/config_options'
require 'rpc_mapper/associations/contains'
require 'rpc_mapper/associations/external'
require 'rpc_mapper/cacheable'
require 'rpc_mapper/serialization'
require 'rpc_mapper/relation'
require 'rpc_mapper/scopes'
require 'rpc_mapper/adapters'


class RPCMapper::Base
  include RPCMapper::ConfigOptions
  include RPCMapper::Associations::Contains
  include RPCMapper::Associations::External
  include RPCMapper::Serialization
  include RPCMapper::Scopes

  attr_accessor :attributes, :new_record
  alias :new_record? :new_record

  class_inheritable_accessor :defined_attributes, :mutable, :cacheable, :scoped_methods, :declared_associations
  config_options :rpc_server_host => 'localhost',
                 :rpc_server_port => 8000,
                 :service => nil,
                 :service_namespace => nil,
                 :adapter_type => nil,
                 # TRP: Only used if configure_mutable is called
                 :mutable_default_parameters => {},
                 :mutable_host => nil,
                 # TRP: This is used to append any options to the call (e.g. value to authenticate the client with the server, :app_key)
                 :default_options => {}

  self.mutable = false
  self.cacheable = false
  self.declared_associations = {}
  self.defined_attributes = []
  @@adapter_pool = {}

  def initialize(attributes={})
    self.new_record = true
    set_attributes(attributes)
  end

  def [](attribute)
    @attributes[attribute.to_s]
  end

  protected

  # TRP: Common interface for setting attributes to keep things consistent
  def set_attributes(attributes)
    attributes = attributes.inject({}) do |options, (key, value)|
      options[key.to_s] = value
      options
    end
    @attributes = {} if @attributes.nil?
    @attributes.merge!(attributes.reject { |field, value| !self.defined_attributes.include?(field) })
  end

  def set_attribute(attribute, value)
    set_attributes({ attribute => value })
  end

  # Class Methods
  class << self
    public

    delegate :find, :first, :all, :search, :to => :scoped
    delegate :select, :group, :order, :joins, :where, :having, :limit, :offset, :from, :to => :scoped

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

    def fetch_records(options={})
      self.adapter.call("#{self.service_namespace}__#{self.service}", options.merge(default_options)).collect { |hash| self.new_from_data_store(hash) }.compact
    end

    def adapter
      @@adapter_pool[self.adapter_type] ||= RPCMapper::Adapters::AbstractAdapter.create(self.adapter_type, { :host => self.rpc_server_host, :port => self.rpc_server_port })
    end

    def method_missing(method, *args, &block)
      if scoped.dynamic_finder_method(method)
        scoped.send(method, *args, &block)
      else
        super
      end
    end

    def configure(options={})
      self.configure_options.each { |option| self.send("#{option}=", options[option]) if options[option] }
    end

    # TRP: Only pulls in mutable module if configure_mutable is called
    def configure_mutable(options={})
      unless mutable
        self.mutable = true

        # TRP: Pull in methods and libraries needed for mutable functionality
        require 'rpc_mapper/mutable'
        self.send(:include, RPCMapper::Mutable)
        self.save_mutable_configuration(options)

        # TRP: Create writers if attributes are declared before configure_mutable is called
        self.defined_attributes.each { |attribute| create_writer(attribute) }
        # TRP: Create serialized writers if attributes are declared serialized before this call
        self.serialized_attributes.each { |attribute| set_serialize_writers(attribute) }
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
        create_writer(attribute) if self.mutable

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

  end

end
