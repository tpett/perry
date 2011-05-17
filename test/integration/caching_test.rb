require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::CachingTest < Test::Unit::TestCase

  context "model with caching middleware with count threshold" do
    setup do
      @model = Class.new(Perry::Test::Base)
      @model.class_eval do
        include Perry::Middlewares::CacheRecords::Scopes

        attributes :id
        configure_read do |config|
          config.add_middleware Perry::Test::FakeAdapterStackItem
          config.add_middleware Perry::Middlewares::CacheRecords, :record_count_threshold => 5
          config.add_middleware Perry::Test::FakeAdapterStackItem
        end
      end
      @adapter = @model.read_adapter
      @adapter.data = { :id => 1 }
      @adapter.count = 1
    end

    teardown do
      @model.reset_cache.first
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

  context "model with caching middleware with default config" do
    setup do
      @model = Class.new(Perry::Test::Base)
      @model.class_eval do
        include Perry::Middlewares::CacheRecords::Scopes

        attributes :id
        configure_read do |config|
          config.add_middleware Perry::Middlewares::CacheRecords
        end
      end
      @adapter = @model.read_adapter
      @adapter.data = { :id => 2 }
      @adapter.count = 1
    end

    teardown do
      @model.reset_cache.first
      @adapter.reset
    end

    should "cache query results with fresh modifier" do
      @model.all
      assert_equal 1, @adapter.calls.size
      @model.all
      assert_equal 1, @adapter.calls.size
    end

    should "not cache when fresh modifier used" do
      @model.all
      assert_equal 1, @adapter.calls.size
      @model.all(:modifiers => { :fresh => true })
      assert_equal 2, @adapter.calls.size

      @model.fresh.all
      assert_equal 3, @adapter.calls.size
      @model.all
      assert_equal 3, @adapter.calls.size
    end

    should "not cache with noop request" do
      @model.modifiers(:noop => true).first
      assert_equal 0, @adapter.calls.size
      @model.first
      assert_equal 1, @adapter.calls.size
    end
  end

  context "model with caching and a write adapter" do
    setup do
      @model = Class.new(Perry::Test::Base)
      @model.class_eval do
        include Perry::Middlewares::CacheRecords::Scopes

        attributes :id
        configure_read do |config|
          config.add_middleware Perry::Middlewares::CacheRecords
        end
        write_with :test
      end
      @adapter = @model.read_adapter
      @adapter.data = { :id => 2 }
      @adapter.count = 1
    end

    teardown do
      @adapter.reset
    end

    should "clear all cache entries for the model on a successful save" do
      @model.all
      @model.all
      # The second .all should be cached
      assert_equal 1, @adapter.calls.size
      @model.new_from_data_store(:id => 1).save
      # One call to save and another to reload the model
      assert_equal 3, @adapter.calls.size
      # This should no longer be cached
      @model.all
      assert_equal 4, @adapter.calls.size
    end

    should "clear all cache entries for the model on a successful delete" do
      @model.all
      @model.all
      # The second .all should be cached
      assert_equal 1, @adapter.calls.size
      @model.new_from_data_store(:id => 1).delete
      # One to delete the record
      assert_equal 2, @adapter.calls.size
      # This shouldn't be cached
      @model.all
      assert_equal 3, @adapter.calls.size
    end

  end
end

