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
      query[:mode] = :read
      log(query, "RPC #{config[:service]}") {
        self.call_server(query)
      }
    end

    def write(options)
      query = options.dup
      object = query.delete(:object)
      if object
        query[:fields] = object.attributes
        if object.new_record?
          query[:mode] = :create
        else
          query[:mode] = :update
          query[:where] = self.where_for_primary_key(object)
        end
      else
        query[:mode] = :update
      end
      log(query, "RPC #{config[:service]}") {
        self.parse_response(self.call_server(query))
      }
    end

    def delete(options)
      query = options.dup
      object = query.delete(:object)
      if object
        query[:where] = self.where_for_primary_key(object)
      end
      log(query, "RPC #{config[:service]}") {
        self.parse_response(self.call_server(query))
      }
    end

    protected

    def call_server(options)
      service_options = (options || {}).dup.merge(config[:default_options])
      request = self.service.call
      namespace = request.send(self.namespace)
      namespace.send(self.service_name, service_options)
    end

    def parse_response(raw)
      response = Perry::Persistence::Response.new
      response.raw = raw

      if raw.key?('fields')
        response.success = true
        response.parsed = raw['fields']
      elsif raw.key?('success')
        response.success = raw['success']
      end

      response
    end

    def where_for_primary_key(object)
      pk_attr = self.config[:primary_key] || object.primary_key
      pk_value = object[pk_attr]
      [{ pk_attr => pk_value }]
    end

    def namespace
      self.config[:namespace]
    end

    def service_name
      self.config[:service]
    end

  end
end
