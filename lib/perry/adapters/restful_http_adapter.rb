autoload :Net, 'net/http'
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

    def write(options)
      object = options[:object]
      params = build_params_from_attributes(object)
      object.new_record? ? post_http(object, params) : put_http(object, params)
    end

    def delete(options)
      delete_http(options[:object])
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

    def build_params_from_attributes(object)
      if self.config[:post_body_wrapper]
        defaults = self.config[:default_options]
        params = defaults ? defaults.dup : {}
        params.merge!(object.write_options[:default_options]) if object.write_options.is_a?(Hash) && object.write_options[:default_options].is_a?(Hash)

        object.attributes.each do |attribute, value|
          params.merge!({"#{self.config[:post_body_wrapper]}[#{attribute}]" => value})
        end

        params
      else
        object.attributes
      end
    end

    def build_uri(object, method)
      url = [self.config[:host].gsub(%r{/$}, ''), self.config[:service]]
      unless object.new_record?
        primary_key = self.config[:primary_key] || object.primary_key
        pk_value = object.send(primary_key) or raise KeyError
        url << pk_value
      end
      uri = URI.parse "#{url.join('/')}#{self.config[:format]}"

      # TRP: method DELETE has no POST body so we have to append any default options onto the query string
      if method == :delete
        uri.query = (self.config[:default_options] || {}).collect { |key, value| "#{key}=#{value}" }.join('&')
      end

      uri
    end

    def http_headers(response)
      response.to_hash.inject({}) do |clean_headers, (key, values)|
        clean_headers.merge(key => values.length > 1 ? values : values.first)
      end
    end

  end
end
