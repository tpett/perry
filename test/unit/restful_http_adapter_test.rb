require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::RestfulHttpAdapterTest < Test::Unit::TestCase

  #-----------------------------------------
  # TRP: Persistence (restful_http adapter test)
  #-----------------------------------------
  context "restful http adapter" do
    setup do
      @model = Class.new(Perry::Test::SimpleModel)
      @model.class_eval do
        attributes :id, :a, :b, :c
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

    # TODO: move to an integration test
    should_eventually "do a PUT when saving an existing record" do
      FakeWeb.register_uri(:put, 'http://test.local/foo/1', :body => "OK")
      instance = @model.new_from_data_store(:id => 1, :a => 'a', :b => 'b', :c => 'c')
      instance.a = 'change'
      assert instance.save
      assert FakeWeb.last_request && FakeWeb.last_request.body_exist?
      assert_kind_of Net::HTTP::Put, FakeWeb.last_request
    end

    # TODO: move to an integration test
    should_eventually "do a POST when saving a new record" do
      @model.class_eval do
        configure_write do |config|
          config.format = '.json'
        end
      end
      FakeWeb.register_uri(:post, 'http://test.local/foo.json', :body => "OK")
      instance = @model.new(:id => 2, :a => 'a', :b => 'b', :c => 'c')
      assert instance.save
      assert FakeWeb.last_request && FakeWeb.last_request.body_exist?
      assert_kind_of Net::HTTP::Post, FakeWeb.last_request
    end

    # TODO: move to an integration test
    should_eventually "do a DELETE when deleting an existing record" do
      FakeWeb.register_uri(:delete, 'http://test.local/foo/1', :body => "OK")
      instance = @model.new_from_data_store(:id => 1, :a => 'a', :b => 'b', :c => 'c')
      assert instance.delete
      assert FakeWeb.last_request
      assert_kind_of Net::HTTP::Delete, FakeWeb.last_request
    end

    # TODO: move to an integration test
    should_eventually "merge in default_options set at the class level" do
      @model.class_eval do
        configure_write do |config|
          config.default_options = { :password => "secret" }
        end
      end
      FakeWeb.register_uri(:put, 'http://test.local/foo/1', :body => "OK")
      instance = @model.new_from_data_store(:id => 1)
      assert instance.save
      assert FakeWeb.last_request
      assert FakeWeb.last_request.body.match(/secret/)
    end

    # TODO: move to an integration test
    should_eventually "merge in default_options set at the instance level" do
      FakeWeb.register_uri(:put, 'http://test.local/foo/1', :body => "OK")
      instance = @model.new_from_data_store(:id => 1)
      instance.write_options = { :default_options => { :api_key => "myapikey" }}
      assert instance.save
      assert FakeWeb.last_request
      assert FakeWeb.last_request.body.match(/myapikey/)
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
      end
    end

  end

end
