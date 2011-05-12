require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::CachingTest < Test::Unit::TestCase

  context "model with caching middleware" do
    setup do
      @model = Class.new(Perry::Test::Base)
      @model.class_eval do
        include Perry::Middlewares::CacheRecords::Scopes
      end
      @model.class_eval do
        attributes :id
        write_with :test
        configure_read do |config|
          config.add_middleware Perry::Test::FakeAdapterStackItem
          config.add_middleware Perry::Middlewares::CacheRecords, :record_count_threshold => 5
          config.add_middleware Perry::Test::FakeAdapterStackItem
        end
      end
      @adapter = @model.write_adapter
      @adapter.data = { :id => 1 }
      @adapter.count = 1
    end

    teardown do
      @adapter.reset
    end

    should "cache requests made below the threshold" do
      @adapter.count = 5
      @model.first
      assert_equal 1, @adapter.calls.size
      @model.first
      assert_equal 1, @adapter.calls.size
    end

    should "not cache requests made above the threshold" do
      @adapter.count = 6
      @model.all
      @model.all
      assert_equal 2, @adapter.calls.size
    end

    should "reexecute queries when fresh modifier present" do
      @model.all
      @model.scoped.fresh.all
      assert_equal 2, @adapter.calls.size

      @model.all
      assert_equal 2, @adapter.calls.size

      @model.all(:modifiers => { :fresh => true })
      assert_equal 3, @adapter.calls.size
    end
  end

end

