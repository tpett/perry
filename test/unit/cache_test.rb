require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::Cacheable::StoreTest < Test::Unit::TestCase

  context "Cacheable::Store instance" do
    setup do
      @lifetime = 5*60
      @store = Perry::Cacheable::Store.new(@lifetime)
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
