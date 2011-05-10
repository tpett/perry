require 'perry/logger'

##
# = Perry::Adapters::AbstractAdapter
#
# This is the base class from which all adapters should inherit from.  Subclasses should overwrite
# one or all of read, write, and/or delete.  They should also register themselves with a
# unique name using the register_as class method.
#
# Adapters contain a stack of code that is executed on each request.  Here is a diagram of the basic
# anatomy of the adaper stack:
#
#   +----------------+
#   |   Perry::Base  |
#   +----------------+
#           |
#   +----------------+
#   |   Processors   |
#   +----------------+
#           |
#   +----------------+
#   |   ModelBridge  |
#   +----------------+
#           |
#   +----------------+
#   |   Middlewares  |
#   +----------------+
#           |
#   +----------------+
#   |     Adapter    |
#   +----------------+
#
# Each request is routed through registred processors, the ModelBridge, and registered middlewares
# before reaching the adapter.  After the adapter does its operation the return value passes through
# each item in the stack allowing stack items to do both custom pre and post processing to every
# request.
#
# == Configuration
#
# You can configure your adapters using the configure method on Perry::Base
#
#   configure(:read) do |config|
#     config.adapter_var_1 = :custom_value
#     config.adapter_var_2 = [:some, :values]
#   end
#
# This block creates a new configuration context.  Each context is merged onto the previous context
# allowing subclasses to override configuration set by their parent class.
#
# == Middlewares
#
# Middlewares allow you to add custom logic between the model and the adapter.  A good example is
# caching.  A caching middleware could be implemented that intercepted a request to the adapter and
# returned the cached value for that request.  If the request is a cache miss it could pass the
# request on to the adapter, and then cache the result for subsequent calls of the same request.
#
# This is an example mof a no-op middleware:
#
#   class NoOpMiddleware
#
#     def initialize(adapter, config={})
#       @adapter = adapter
#       @config = config
#     end
#
#     def call(options)
#       @adapter.call(options)
#     end
#
#   end
#
# Though this doesn't do anything it serves to demonstrate the basic structure of a middleware.
# Logic could be added to perform caching, custom querying, or custom result processing.
#
# Middlewares can also be chained to perform several independent actions.  Middlewares are configured
# through a custom configuration method:
#
#   configure(:read) do |config|
#     config.add_middleware(MyMiddleware, :config => 'var', :foo => 'bar')
#   end
#
# == ModelBridge
#
# The ModelBridge is simply a middleware that is always installed.  It instantiates the records from
# the data returned by the adapter.  It "bridges" the raw data to the mapped object.
#
# == Processors
#
# Much like middlewares, processors allow you to insert logic into the request stack.  The
# differentiation is that processors are able to manipulate the instantiated objects rather than
# just the raw data.  Processors have access to the objects immediately before passing the data back
# to the model space.
#
# The interface for a processor is identical to that of a middleware.  The return value of the call
# to adapter; however, is an array of Perry::Base objects rather than Hashes of attributes.
#
# Configuration is also very similar to middlewares:
#
#   configure(:read) do |config|
#     config.add_processor(MyProcessor, :config => 'var', :foo => 'bar')
#   end
#
#
class Perry::Adapters::AbstractAdapter
  include Perry::Logger

  attr_accessor :config
  attr_reader :type
  @@registered_adapters ||= {}

  # Accepts type as :read, :write, or :delete and a base configuration context for this adapter.
  def initialize(type, config)
    @type = type.to_sym
    @configuration_contexts = config.is_a?(Array) ? config : [config]
  end

  # Wrapper to the standard init method that will lookup the adapter's class based on its registered
  # symbol name.
  def self.create(type, config)
    klass = @@registered_adapters[type.to_sym]
    klass.new(type, config)
  end

  # Return a new adapter of the same type that adds the given configuration context
  def extend_adapter(config)
    config = config.is_a?(Array) ? config : [config]
    self.class.create(self.type, @configuration_contexts + config)
  end

  # return the merged configuration object
  def config
    @config ||= build_configuration
  end

  # runs the adapter in the specified type mode -- designed to work with the middleware stack
  def call(mode, options)
    @stack ||= self.stack_items.inject(self.method(mode)) do |below, (above_klass, above_config)|
      above_klass.new(below, above_config)
    end

    @stack.call(options)
  end

  # Return an array of added middlewares
  def middlewares
    self.config[:middlewares] || []
  end

  # Return an array of added processors
  def processors
    self.config[:processors] || []
  end

  # Abstract read method -- overridden by subclasses
  def read(options)
    raise(NotImplementedError,
          "You must not use the abstract adapter.  Implement an adapter that extends the " +
          "Perry::Adapters::AbstractAdapter class and overrides this method.")
  end

  # Abstract write method -- overridden by subclasses
  def write(object)
    raise(NotImplementedError,
          "You must not use the abstract adapter.  Implement an adapter that extends the " +
          "Perry::Adapters::AbstractAdapter class and overrides this method.")
  end

  # Abstract delete method -- overridden by subclasses
  def delete(object)
    raise(NotImplementedError,
          "You must not use the abstract adapter.  Implement an adapter that extends the " +
          "Perry::Adapters::AbstractAdapter class and overrides this method.")
  end

  # New adapters should register themselves using this method
  def self.register_as(name)
    @@registered_adapters[name.to_sym] = self
  end

  protected

  def stack_items
    (processors + [Perry::Middlewares::ModelBridge] + middlewares).reverse
  end

  # TRP: Run each configure block in order of class hierarchy / definition and merge the results.
  def build_configuration
    @configuration_contexts.inject({}) do |sum, config|
      if config.is_a?(Hash)
        sum.merge(config)
      else
        AdapterConfig.new(sum).tap { |ac| config.call(ac) }.marshal_dump
      end
    end
  end

  class AdapterConfig < OpenStruct

    def add_middleware(klass, config={})
      self.middlewares ||= []
      self.middlewares << [klass, config]
    end

    def add_processor(klass, config={})
      self.processors ||= []
      self.processors << [klass, config]
    end

    def to_hash
      marshal_dump
    end

  end

end

