require 'net/http'
require 'uri'

module RPCMapper

  module Mutable

    module ClassMethods

      protected

      def save_mutable_configuration(options={})
        self.mutable_service = options[:service] || self.service
        self.mutable_post_body_wrapper = options[:post_body_wrapper]
      end

      def create_writer(attribute)
        define_method("#{attribute}=") do |value|
          self[attribute] = value
        end
      end

    end


    module InstanceMethods

      def []=(attribute, value)
        set_attribute(attribute, value)
      end

      def attributes=(attributes)
        set_attributes(attributes)
      end

      def save
        new_record? ? post_http(build_params_from_attributes) : put_http(build_params_from_attributes)
      end

      def update_attributes(attributes)
        self.attributes = attributes
        save
      end

      def destroy
        delete_http
      end
      alias :delete :destroy


      protected


      def post_http(params)
        http_call(:post, params)
      end

      def put_http(params)
        http_call(:put, params)
      end

      def delete_http
        http_call(:delete, self.mutable_default_parameters)
      end

      def http_call(method, params={})
        request_klass = case method
        when :post    then Net::HTTP::Post
        when :put     then Net::HTTP::Put
        when :delete  then Net::HTTP::Delete
        end

        req_url = self.build_url(method)

        request = if method == :delete
          request = request_klass.new([req_url.path, req_url.query].join('?'))
        else
          request = request_klass.new(req_url.path)
          request.set_form_data(params) unless method == :delete
          request
        end

        self.class.send(:adapter).log(params, "#{method.to_s.upcase} #{req_url}") do
          @response = Net::HTTP.new(req_url.host, req_url.port).start { |http| http.request(request) }
        end
        parse_response_code(@response)
      end

      def parse_response_code(response)
        case response
        when Net::HTTPSuccess, Net::HTTPRedirection
          true
        else
          false
        end
      end

      def build_params_from_attributes
        if self.mutable_post_body_wrapper
          params = self.mutable_default_parameters
          @attributes.each do |attribute, value|
            params.merge!({"#{self.mutable_post_body_wrapper}[#{attribute}]" => value})
          end
          # TRP: Append ivar mutable_params to params if set
          params.merge!(self.mutable_params) if self.mutable_params.is_a?(Hash)

          params
        else
          @attributes
        end
      end

      def build_url(method)
        url = [self.mutable_host.gsub(%r{/$}, ''), self.mutable_service]
        url << self.id unless self.new_record?
        uri = URI.parse "#{url.join('/')}.json"

        if method == :delete
          uri.query = self.mutable_default_parameters.collect { |key, value| "#{key}=#{value}" }.join('&')
        end

        uri
      end

    end

    def self.included(receiver)
      receiver.class_inheritable_accessor :mutable_service, :mutable_post_body_wrapper
      receiver.send :attr_accessor, :mutable_params
      receiver.send(:attr_accessor, :response)

      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end

  end

end
