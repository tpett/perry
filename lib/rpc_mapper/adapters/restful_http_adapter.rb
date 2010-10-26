autoload :Net, 'net/http'
autoload :URI, 'uri'

module RPCMapper::Adapters
  class RestfulHTTPAdapter < RPCMapper::Adapters::AbstractAdapter
    register_as :restful_http

    attr_reader :last_response

    def write(object)
      params = build_params_from_attributes(object)
      object.new_record? ? post_http(object, params) : put_http(object, params)
    end

    def delete(object)
      delete_http(object)
    end

    protected

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
      when :post    then Net::HTTP::Post
      when :put     then Net::HTTP::Put
      when :delete  then Net::HTTP::Delete
      end

      req_uri = self.build_uri(object, method)

      request = if method == :delete
        request = request_klass.new([req_uri.path, req_uri.query].join('?'))
      else
        request = request_klass.new(req_uri.path)
        request.set_form_data(params) unless method == :delete
        request
      end

      self.log(params, "#{method.to_s.upcase} #{req_uri}") do
        @last_response = Net::HTTP.new(req_uri.host, req_uri.port).start { |http| http.request(request) }
      end
      parse_response_code(@last_response)
    end

    def parse_response_code(response)
      case response
      when Net::HTTPSuccess, Net::HTTPRedirection
        true
      else
        false
      end
    end

    def build_params_from_attributes(object)
      if self.config[:post_body_wrapper]
        params = self.config[:default_options] || {}

        object.attributes.each do |attribute, value|
          params.merge!({"#{self.config[:post_body_wrapper]}[#{attribute}]" => value})
        end

        params
      else
        @attributes
      end
    end

    def build_uri(object, method)
      url = [self.config[:host].gsub(%r{/$}, ''), self.config[:service]]
      url << object.id unless object.new_record?
      uri = URI.parse "#{url.join('/')}#{self.config[:format]}"

      # TRP: method DELETE has no POST body so we have to append any default options onto the query string
      if method == :delete
        uri.query = (self.config[:default_options] || {}).collect { |key, value| "#{key}=#{value}" }.join('&')
      end

      uri
    end

  end
end
