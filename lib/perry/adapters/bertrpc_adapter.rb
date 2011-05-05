autoload :BERTRPC, 'bertrpc'

module Perry::Adapters
  class BERTRPCAdapter < Perry::Adapters::AbstractAdapter
    register_as :bertrpc

    @@service_pool ||= {}

    def service
      @@service_pool["#{config[:host]}:#{config[:port]}"] ||=
          BERTRPC::Service.new(self.config[:host], self.config[:port])
    end

    def read(options)
      query = options[:relation].to_hash
      log(query, "RPC #{config[:service]}") {
        self.service.call.send(self.namespace).send(self.service_name,
                                                    query.merge(config[:default_options] || {}))
      }
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
