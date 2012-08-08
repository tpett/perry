require "#{File.dirname(__FILE__)}/../test_helper"


class Perry::AdapterStackTest < Test::Unit::TestCase

  context "model with middlewares and adapters configured" do
    setup do
      Perry::Test::FakeAdapterStackItem.reset
      class MiddlewareA < Perry::Test::FakeAdapterStackItem; end
      class ProcessorA < Perry::Test::FakeAdapterStackItem; end

      @model = Class.new(Perry::Test::Base)
      @model.class_eval do
        attributes :id, :a, :b, :c

        configure_read do |config|
          config.add_middleware MiddlewareA
          config.add_processor ProcessorA
        end

        write_with :restful_http

        configure_write do |config|
          config.host = 'http://test.local'
          config.service = 'foo'
          config.post_body_wrapper = 'foo'
          config.format = '.json'
          config.add_processor ProcessorA
          config.add_middleware MiddlewareA
        end
      end
      @adapter = @model.read_adapter
      @adapter.count = 1
      @adapter.data = { :id => 1 }
    end

    teardown do
      FakeWeb.clean_registry
    end

    should "hit the whole adapter stack with any query" do
      @adapter.data = { :id => 1 }
      relation = @model.where(:id => 1)
      result = relation.to_a

      correct = [
        [ 'ProcessorA', {}, { :relation => relation, :mode => :read } ],
        [ 'MiddlewareA', {}, { :relation => relation, :mode => :read } ],
        [ Hash ],
        [ @model ]
      ]

      assert_equal correct, Perry::Test::FakeAdapterStackItem.log
      assert !result.first.new_record?
    end

    should "hit the whole adapter stack with any save" do
      FakeWeb.register_uri(:post,
        'http://test.local/foo.json',
        :body => { 'id' => 1 }.to_json
      )
      object = @model.new
      object.save

      correct = [
        [ 'ProcessorA', {}, { :object => object, :mode => :write } ],
        [ 'MiddlewareA', {}, { :object => object, :mode => :write } ],
      ]

      assert_equal correct, Perry::Test::FakeAdapterStackItem.log[0..1]
      assert_equal 1, object.id
    end

    should "hit the whole adapter stack with any delete" do
      FakeWeb.register_uri(:delete,
        'http://test.local/foo/1.json',
        :body => "OK"
      )
      object = @model.new_from_data_store({ :id => 1 })
      object.delete

      correct = [
        [ 'ProcessorA', {}, { :object => object, :mode => :delete } ],
        [ 'MiddlewareA', {}, { :object => object, :mode => :delete } ],
      ]

      assert_equal correct, Perry::Test::FakeAdapterStackItem.log[0..1]
    end

    should "set errors on base model on failed save if present in response" do
      FakeWeb.register_uri(:post,
        'http://test.local/foo.json',
        :body => { 'name' => "can't be blank" }.to_json,
        :status => [422, "Unprocessable Entity"]
      )
      object = @model.new
      object.save
      assert_equal({ :name => "can't be blank" }, object.errors)
    end

    should "do a PUT when saving an existing record" do
      FakeWeb.register_uri(:put, 'http://test.local/foo/1.json', :body => "")
      instance = @model.new_from_data_store(:id => 1, :a => 'a', :b => 'b', :c => 'c')
      instance.a = 'change'
      assert instance.save
      assert FakeWeb.last_request && FakeWeb.last_request.body_exist?
      assert_kind_of Net::HTTP::Put, FakeWeb.last_request
    end

    should "do a POST when saving a new record" do
      FakeWeb.register_uri(:post, 'http://test.local/foo.json', :body => { :id => 2 }.to_json)
      instance = @model.new(:a => 'a', :b => 'b', :c => 'c')
      @adapter.data = instance.attributes.merge(:id => 2)
      assert instance.save
      assert FakeWeb.last_request && FakeWeb.last_request.body_exist?
      assert_kind_of Net::HTTP::Post, FakeWeb.last_request
      assert_equal 2, instance.id
    end

    should "do a DELETE when deleting an existing record" do
      FakeWeb.register_uri(:delete, 'http://test.local/foo/1.json', :body => "")
      instance = @model.new_from_data_store(:id => 1, :a => 'a', :b => 'b', :c => 'c')
      assert instance.delete
      assert FakeWeb.last_request
      assert_kind_of Net::HTTP::Delete, FakeWeb.last_request
    end

    should "put default_options set at the class level in the query string" do
      @model.class_eval do
        configure_write do |config|
          config.default_options = { :password => "secret" }
        end
      end
      FakeWeb.register_uri(:put, 'http://test.local/foo/1.json?password=secret', :body => "OK")
      instance = @model.new_from_data_store(:id => 1)
      assert instance.save
      assert FakeWeb.last_request
      assert FakeWeb.last_request.path.match(/\?password=secret/)
    end

    should "put default_options set at the instance level in the query string" do
      FakeWeb.register_uri(:put, 'http://test.local/foo/1.json?api_key=myapikey', :body => "OK")
      instance = @model.new_from_data_store(:id => 1)
      instance.write_options = { :default_options => { :api_key => "myapikey" }}
      assert instance.save
      assert FakeWeb.last_request
      assert FakeWeb.last_request.path.match(/\?api_key=myapikey/)
    end
  end

end

