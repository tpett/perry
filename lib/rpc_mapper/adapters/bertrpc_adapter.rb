autoload :BERTRPC, 'bertrpc'

module RPCMapper::Adapters
  class BERTRPCAdapter < RPCMapper::Adapters::AbstractAdapter
    register_as :bertrpc

    @@service_pool ||= {}

    def service
      @@service_pool["#{config[:host]}:#{config[:port]}"] ||= BERTRPC::Service.new(self.config[:host], self.config[:port])
    end

    def read(options)
      log(options, "RPC #{config[:service]}") { self.service.call.send(self.namespace).send(self.service_name, options.merge(config[:default_options] || {})) }
    end

    protected

    def namespace
      self.config[:namespace]
    end

    def service_name
      self.config[:service]
    end

  end
end
