module Net
  autoload :HTTP, 'net/http'
end
autoload :URI, 'uri'

module Perry::Adapters
  class RestfulHTTPAdapter < Perry::Adapters::AbstractAdapter
    register_as :restful_http

    class KeyError < Perry::PerryError
      def message
        '(restful_http_adapter) request not sent because primary key value was nil'
      end
    end

    attr_reader :last_response

    def read(options)
      response = get_http(options[:relation])
      unless response.parsed.is_a?(Array)
        raise Perry::MalformedResponse, "Expected instance of Array got '#{response.raw.inspect}'"
      end
      response.array_attributes
    end

    def write(options)
      object = options[:object]
      params = build_write_params_from_attributes(object)
      object.new_record? ? post_http(object, params) : put_http(object, params)
    end

    def delete(options)
      delete_http(options[:object])
    end

    protected

    def get_http(relation)
      http_call(relation, :get, relation.to_hash.merge(relation.modifiers_value[:query] || {}))
    end

    def post_http(object, params)
      http_call(object, :post, params)
    end

    def put_http(object, params)
      http_call(object, :put, params)
    end

    def delete_http(object)
      http_call(object, :delete, self.config[:default_options])
    end

    def http_call(object, method, params={})
      request_klass = case method
      when :get     then Net::HTTP::Get
      when :post    then Net::HTTP::Post
      when :put     then Net::HTTP::Put
      when :delete  then Net::HTTP::Delete
      end

      req_uri = self.build_uri(object, method, params || {})
      request = request_klass.new([req_uri.path, req_uri.query].join('?'))
      if [:post, :put].include?(method)
        request.set_form_data(params)
      end

      self.log(params, "#{method.to_s.upcase} #{req_uri}") do
        @last_response = Net::HTTP.new(req_uri.host, req_uri.port).start { |http| http.request(request) }
      end

      Perry::Persistence::Response.new.tap do |response|
        response.status = @last_response.code.to_i if @last_response
        response.success = parse_response_code(@last_response)
        response.meta = http_headers(@last_response).to_hash if @last_response
        response.raw = @last_response.body if @last_response
        response.raw_format = config[:format] ? config[:format].gsub(/\W/, '').to_sym : nil
      end
    rescue KeyError => ex
      Perry::Persistence::Response.new.tap do |response|
        response.success = false
        response.parsed = { :base => ex.message }
      end
    end

    def parse_response_code(response)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        true
      else
        false
      end
    end

    def build_write_params_from_attributes(object)
      if self.config[:post_body_wrapper]
        params = {}
        object.attributes.each do |attribute, value|
          params.merge!({"#{self.config[:post_body_wrapper]}[#{attribute}]" => value})
        end
        params
      else
        object.attributes
      end
    end

    def build_uri(object, method, params={})
      url = [self.config[:host].gsub(%r{/$}, ''), self.config[:service]]
      if object.is_a?(Perry::Base) && !object.new_record?
        primary_key = self.config[:primary_key] || object.primary_key
        pk_value = object.send(primary_key) or raise KeyError
        url << pk_value
      end

      uri = URI.parse "#{url.join('/')}#{self.config[:format]}"

      # append any config `:default_options` and any object `:default_options`
      # onto the query string.  if GET or DELETE, also append the params
      # since they don't use a post body
      defaults = self.config[:default_options] || {}
      if object.respond_to?(:write_options) && object.write_options.is_a?(Hash) && object.write_options[:default_options].is_a?(Hash)
        defaults.merge!(object.write_options[:default_options])
      end
      uri.query = if [:get, :delete].include?(method)
        defaults.merge(params)
      else
        defaults
      end.to_query

      uri
    end

    def http_headers(response)
      response.to_hash.inject({}) do |clean_headers, (key, values)|
        clean_headers.merge(key => values.length > 1 ? values : values.first)
      end
    end

  end
end
