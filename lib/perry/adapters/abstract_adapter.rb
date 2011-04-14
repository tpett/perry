require 'perry/logger'

module Perry::Adapters
  class AbstractAdapter
    include Perry::Logger

    attr_accessor :config
    attr_reader :type
    @@registered_adapters ||= {}

    def initialize(type, config)
      @type = type.to_sym
      @configuration_contexts = config.is_a?(Array) ? config : [config]
    end

    def self.create(type, config)
      klass = @@registered_adapters[type.to_sym]
      klass.new(type, config)
    end

    def extend_adapter(config)
      config = config.is_a?(Array) ? config : [config]
      self.class.create(self.type, @configuration_contexts + config)
    end

    def config
      @config ||= build_configuration
    end

    def call(mode, options)
      @stack ||= self.middlewares.reverse.inject(self.method(mode)) do |below, (above_klass, above_config)|
        above_klass.new(below, above_config)
      end

      @stack.call(options)
    end

    def middlewares
      self.config[:middlewares] || []
    end

    def read(options)
      raise(NotImplementedError,
            "You must not use the abstract adapter.  Implement an adapter that extends the " +
            "Perry::Adapters::AbstractAdapter class and overrides this method.")
    end

    def write(object)
      raise(NotImplementedError,
            "You must not use the abstract adapter.  Implement an adapter that extends the " +
            "Perry::Adapters::AbstractAdapter class and overrides this method.")
    end

    def delete(object)
      raise(NotImplementedError,
            "You must not use the abstract adapter.  Implement an adapter that extends the " +
            "Perry::Adapters::AbstractAdapter class and overrides this method.")
    end

    def self.register_as(name)
      @@registered_adapters[name.to_sym] = self
    end

    private

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

      def to_hash
        marshal_dump
      end

    end

  end
end

