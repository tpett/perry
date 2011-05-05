require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::RestfulHttpAdapterTest < Test::Unit::TestCase

  #-----------------------------------------
  # TRP: Persistence (restful_http adapter test)
  #-----------------------------------------
  context "restful http adapter" do
    setup do
      @model = Class.new(Perry::Test::Base)
      @model.class_eval do
        attributes :id, :a, :b, :c
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

    should "do a PUT when saving an existing record" do
      FakeWeb.register_uri(:put, 'http://test.local/foo/1', :body => "OK")
      instance = @model.new_from_data_store(:id => 1, :a => 'a', :b => 'b', :c => 'c')
      instance.a = 'change'
      assert instance.save
      assert FakeWeb.last_request && FakeWeb.last_request.body_exist?
      assert_kind_of Net::HTTP::Put, FakeWeb.last_request
    end

    should "do a POST when saving a new record" do
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

    should "do a DELETE when deleting an existing record" do
      FakeWeb.register_uri(:delete, 'http://test.local/foo/1', :body => "OK")
      instance = @model.new_from_data_store(:id => 1, :a => 'a', :b => 'b', :c => 'c')
      assert instance.delete
      assert FakeWeb.last_request
      assert_kind_of Net::HTTP::Delete, FakeWeb.last_request
    end

    should "merge in default_options set at the class level" do
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

    should "merge in default_options set at the instance level" do
      FakeWeb.register_uri(:put, 'http://test.local/foo/1', :body => "OK")
      instance = @model.new_from_data_store(:id => 1)
      instance.write_options = { :default_options => { :api_key => "myapikey" }}
      assert instance.save
      assert FakeWeb.last_request
      assert FakeWeb.last_request.body.match(/myapikey/)
    end

    should "use :id for the default primary_key" do
      assert_equal :id, @model.write_adapter.config[:primary_key]
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
