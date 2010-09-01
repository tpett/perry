module RPCMapper::Adapters
  class BERTRPCAdapter < RPCMapper::Adapters::AbstractAdapter
    register_as :bertrpc

    def service
      @service ||= BERTRPC::Service.new(self.options[:host], self.options[:port])
    end

  end
end
