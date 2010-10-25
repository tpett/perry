require 'rpc_mapper/logger'

module RPCMapper::Adapters
  class AbstractAdapter
    include RPCMapper::Logger

    attr_accessor :config
    attr_reader :type
    @@registered_adapters ||= {}
    class_inheritable_accessor :configuration_contexts
    self.configuration_contexts = []

    def initialize(type, config)
      @type = type.to_sym
      self.configuration_contexts << config
    end

    def self.create(type, config)
      klass = type ? @@registered_adapters[type.to_sym] : self
      klass.new(type, config)
    end

    def extend_adapter(config)
      self.class.create(self.type, config)
    end

    def config
      @config ||= build_configuration
    end

    def read(options)
      raise NotImplementedError, "You must not use the abstract adapter.  Implement an adapter that extends the RPCMapper::Adapters::Abstract::Base class and overrides this method."
    end

    def write(object)
      raise NotImplementedError, "You must not use the abstract adapter.  Implement an adapter that extends the RPCMapper::Adapters::Abstract::Base class and overrides this method."
    end

    def delete(object)
      raise NotImplementedError, "You must not use the abstract adapter.  Implement an adapter that extends the RPCMapper::Adapters::Abstract::Base class and overrides this method."
    end

    def self.register_as(name)
      @@registered_adapters[name.to_sym] = self
    end

    private

    # TRP: Run each configure block in order of class hierarchy / definition and merge the results.
    def build_configuration
      self.configuration_contexts.collect do |config_block|
        config_block.is_a?(Hash) ? config_block : OpenStruct.new.tap { |os| config_block.call(os) }.marshal_dump
      end.inject({}) { |sum, config| sum.merge(config) }
    end

  end
end
