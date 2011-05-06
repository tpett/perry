require "#{File.dirname(__FILE__)}/../../test_helper"

class Perry::Middlewares::CacheRecordsTest < Test::Unit::TestCase

  context "cache records middleware" do
    setup do
      @klass = Class.new(Perry::Test::Base)
      @relation = @klass.send(:relation)
      @options = { :relation => @relation }
      @adapter = Perry::Test::MiddlewareAdapter.new(:read, {})
      @adapter.reset
      @adapter.data = { :id => 1, :name => "Foo", :expire_at => Time.now + 60 }

      @config = {
        :expires => :expire_at,
        :record_count_threshold => 5
      }
      @middleware = Perry::Middlewares::CacheRecords.new(@adapter, @config)
      @middleware.reset_cache_store
    end

    context "configuration" do
      should "set the configuration variables" do
        assert_equal @config[:expires], @middleware.send(:expires)
        assert_equal @config[:record_count_threshold], @middleware.send(:record_count_threshold)
      end
    end

    should "only execute one call for two duplicate requests" do
      assert_equal @middleware.call(@options), @middleware.call(@options)
      assert_equal 1, @adapter.calls.size
    end

    should "only cache if the record count is within threshold" do
      @middleware.call({ :relation => @relation.limit(@middleware.record_count_threshold + 1) })
      @middleware.call({ :relation => @relation.limit(@middleware.record_count_threshold + 1) })
      assert_equal 2, @adapter.calls.size
    end

    should "rerun query if cache is expired" do
      @middleware.expires = nil
      @middleware.reset_cache_store(0)
      @middleware.call(@options)
      @middleware.call(@options)
      assert_equal 2, @adapter.calls.size
    end

    # TODO: we currently don't have a way to do this now that caching is handled in a middleware
    should_eventually "set fresh to false if data is from cache and to true if data is not from cache" do
      assert @model.first.fresh
      assert !@model.first.fresh
    end

    should "rerun query if fresh modifier is used" do
      options = { :relation => @relation.modifiers(:fresh => true) }
      assert_equal @middleware.call(options), @middleware.call(options)
      assert_equal 2, @adapter.calls.size
    end

    context "cache store" do
      setup do
        @other_middleware = Perry::Middlewares::CacheRecords.new(@adapter, @config)
      end

      teardown do
        @other_middleware.reset_cache_store
      end

      should "exist" do
        assert @middleware.respond_to?(:cache_store)
        assert @middleware.cache_store.kind_of?(Perry::Middlewares::CacheRecords::Store)
      end

      should "be resetabble" do
        @middleware.call(@options)
        @middleware.call(:relation => @relation.modifiers(:reset_cache => true))
        assert_equal 2, @adapter.calls.size
      end

      should "be shared across caching middleware instances" do
        @middleware.call(@options)
        @other_middleware.call(@options)
        assert_equal 1, @adapter.calls.size
      end
    end
  end

  context "CacheRecords::Store instance" do
    setup do
      @lifetime = 5*60
      @store = Perry::Middlewares::CacheRecords::Store.new(@lifetime)
    end

    should "set default_longevity" do
      assert_equal @lifetime, @store.default_longevity
    end

    context "write method" do
      setup do
        @store.write("foo", "bar")
      end

      should "write value to store" do
        assert_equal "bar", @store.store["foo"].value
      end

      should "create an entry for key with expire time @lifetime from now" do
        assert_in_delta Time.now + @lifetime, @store.store["foo"].expire_at, 1
      end

      should "create an entry for key with expire time equal to param if param sent" do
        expire = Time.now
        @store.write("duck", "soup", expire)
        assert_equal expire, @store.store['duck'].expire_at
      end

      should "clear out expired entries on write" do
        @store.write("duck", "soup", Time.now)
        @store.write("happy", "chainsaw")
        assert_nil @store.store['duck']
      end

    end

    context "read method" do

      should "return the value of key if present and not expired" do
        @store.write 'foo', 'bar'
        assert_equal 'bar', @store.read('foo')
      end

      should "return nil if value of key is presnet and expired" do
        @store.write 'foo', 'bar', Time.now
        assert_nil @store.read('foo')
      end

      should "return nil if value of key is not present" do
        @store.write 'foo', 'bar'
        assert_nil @store.read('baz')
      end
    end

    context "clear method" do
      setup do
        @store.write 'foo', 'bar'
        @store.write 'expired', 'key', Time.now
      end

      should "only remove entry for key if provided" do
        @store.clear('foo')
        assert_nil @store.store['foo']
        assert @store.store['expired']
      end

      should "remove all expired items if no key provided" do
        @store.clear
        assert_nil @store.store['expired']
        assert @store.store['foo']
      end

    end
  end

end
