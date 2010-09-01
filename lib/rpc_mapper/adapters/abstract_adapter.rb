require 'rpc_mapper/logger'

module RPCMapper::Adapters
  class AbstractAdapter
    include RPCMapper::Logger

    attr_accessor :options
    @@registered_adapters ||= {}

    def initialize(options={})
      @options = options.dup
    end

    def self.create(type, options={})
      type = type ? @@registered_adapters[type.to_sym] : self
      type.new(options)
    end

    def call(procedure, options={})
      log(options, "#{service_log_prefix} #{procedure}") { self.service.call.data_server.send(procedure, options) }
    end

    def service
      raise NotImplementedError, "You must not use the AbstractAdapter.  Implement an adapter that extends the AbstractAdapter class and overrides this method."
    end

    def service_log_prefix
      "RPC"
    end

    def self.register_as(name)
      @@registered_adapters[name.to_sym] = self
    end

  end
end
