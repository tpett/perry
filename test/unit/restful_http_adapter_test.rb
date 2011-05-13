require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::RestfulHttpAdapterTest < Test::Unit::TestCase

  #-----------------------------------------
  # TRP: Persistence (restful_http adapter test)
  #-----------------------------------------
  context "restful http adapter" do
    setup do
      @model = Class.new(Perry::Test::SimpleModel)
      @model.class_eval do
        attributes :id
        read_with :test
        write_with :restful_http
        configure_write do |config|
          config.host = 'http://test.local'
          config.service = 'foo'
          config.post_body_wrapper = 'foo'
        end
      end
    end

    teardown do
      FakeWeb.clean_registry
    end

    [:post, :put, :delete].each do |http_method|
      new_record = http_method == :put
      test_method = http_method == :delete ? :delete : :write

      context "##{test_method} method for #{new_record ? 'a new' : 'an existing'} record" do
        setup do
          @model.class_eval do
            configure_write do |config|
              config.format = '.json'
            end
          end
          @instance = @model.new

          case http_method
          when :post
            @uri = 'http://test.local/foo.json'
          when :put, :delete
            @instance.id = 1
            @instance.new_record = false
            @uri = "http://test.local/foo/#{@instance.id}.json"
          end

          @adapter_method = test_method
        end

        teardown do
          FakeWeb.last_request = nil
        end

        should "return a Response object" do
          FakeWeb.register_uri(http_method, @uri, :body => 'OK')
          @response = @model.write_adapter.send(@adapter_method, :object => @instance)
          assert @response.is_a?(Perry::Persistence::Response)
        end

        should "set Response#status to HTTP status" do
          FakeWeb.register_uri(http_method, @uri, :body => 'OK')
          @response = @model.write_adapter.send(@adapter_method, :object => @instance)
          assert_equal 200, @response.status
        end

        should "set Response#success to true if status indicates success" do
          FakeWeb.register_uri(http_method, @uri, :body => 'OK')
          @response = @model.write_adapter.send(@adapter_method, :object => @instance)
          assert @response.success
        end

        should "set Response#success to false if status indicates failure or is unkown" do
          FakeWeb.register_uri(http_method, @uri, :body => 'oops!', :status => [500, 'Error'])
          @response = @model.write_adapter.send(@adapter_method, :object => @instance)
          assert !@response.success
        end

        should "set Response#meta to a hash of the HTTP response headers" do
          FakeWeb.register_uri(http_method, @uri, :response => mock_http_response('json_response'))
          @response = @model.write_adapter.send(@adapter_method, :object => @instance)
          headers = { 'server' => 'test', 'content-type' => 'application/json' }
          assert_equal headers, @response.meta
        end

        should "set Response#raw to the unmodified HTTP response body" do
          fake_response = mock_http_response('json_response')
          FakeWeb.register_uri(http_method, @uri, :response => fake_response)
          @response = @model.write_adapter.send(@adapter_method, :object => @instance)
          assert_equal fake_response.split(/\r\n\r\n/)[1], @response.raw
        end

        should "set Response#raw_format to the correct format" do
          FakeWeb.register_uri(http_method, @uri, :body => 'OK')
          @response = @model.write_adapter.send(@adapter_method, :object => @instance)
          assert_equal :json, @response.raw_format
        end

        unless http_method == :post
          should "return a failure response if object's primary key value is nil" do
            @instance.id = nil
            FakeWeb.register_uri(http_method, @uri, :body => 'OK')

            assert_nothing_raised do
              @response = @model.write_adapter.send(@adapter_method, :object => @instance)
            end

            assert_nil FakeWeb.last_request
            assert_equal false, @response.success
            assert_equal Perry::Adapters::RestfulHTTPAdapter::KeyError.new.message, @response.errors[:base]
          end
        end

        unless http_method == :delete
          should "not alter config[:default_options] when config[:post_body_wrapper] is set" do
            FakeWeb.register_uri(http_method, @uri, :response => mock_http_response('json_response'))

            @model.class_eval do
              attributes :foo
              configure_write do |config|
                config.post_body_wrapper = 'model'
                config.default_options = { :api_key => 'asdf' }
              end
            end

            @instance.foo = 'foo'

            old_defaults = @model.write_adapter.config[:default_options].dup
            @response = @model.write_adapter.send(@adapter_method, :object => @instance)
            assert_equal old_defaults, @model.write_adapter.config[:default_options]
          end
        end
      end
    end

    should "allow configuration of the primary_key" do
      pk = :custom
      @model.clone.tap do |model|
        model.class_eval do
          configure_write { |config| config.primary_key = pk }
        end
        assert_equal pk, model.write_adapter.config[:primary_key]
      end
    end

  end

end
