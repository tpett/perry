require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::CachingTest < Test::Unit::TestCase

  context "Caching class" do

    setup do
      # Shield these tests from the rest of the suite
      @klass = Class.new(Perry::Caching)
    end

    teardown do
      @klass.clean_registry
    end

    context "reset class method" do

      should "exist" do
        assert @klass.respond_to?(:reset)
      end

      should "reset each registered cache" do
        calls = []
        @klass.register { calls << :block }
        @klass.register(proc { calls << :proc })
        @klass.reset
        assert_equal [:block, :proc], calls
      end

    end

    context "registering methods" do

      should "have register class method" do
        assert @klass.respond_to?(:register)
      end

      should "have registered class method that returns an array" do
        assert @klass.respond_to?(:registered)
        assert @klass.registered.is_a?(Array)
      end

      should "register with a bound method or block and append it to an array" do
        test_proc = proc { "FOO" }
        assert_equal -1, @klass.method(:register).arity
        @klass.register(&test_proc)
        assert_equal 1, @klass.registered.size
        @klass.register(test_proc)
        assert_equal 2, @klass.registered.size
        assert_equal [test_proc, test_proc], @klass.registered
      end

    end

    should "allow enabling and disabling through enable and disable methods" do
      assert !@klass.enabled?
      @klass.enable
      assert @klass.enabled?
      @klass.disable
      @klass.enable
      @klass.enable
      assert @klass.enabled?
      @klass.disable
      assert !@klass.enabled?
    end

    context "use method" do
      should "accept and yield to a block" do
        called = false
        @klass.use { called = true }
        assert called
      end

      should "set enabled flag to true within block if false before and return it to false" do
        assert !@klass.enabled?
        @klass.use { assert @klass.enabled? }
        assert !@klass.enabled?
      end

      should "not change enabled flag if true when method called" do
        @klass.enable
        @klass.use { assert @klass.enabled? }
        assert @klass.enabled?
      end

      should "call reset after block" do
        reset = false
        @klass.register { reset = true }
        @klass.use {}
        assert reset
      end

      should "reset and set enabled when exception raised in block and then reraise" do
        reset = false
        @klass.register { reset = true }
        assert_raises(RuntimeError) { @klass.use { raise "Testing 1 2 3" } }
        assert reset
        assert !@klass.enabled?
      end

    end

    context "forgo method" do
      should "accept and yield to a block" do
        called = false
        @klass.forgo { called = true }
        assert called
      end

      should "set enabled flag to false within block if true before and return it to true" do
        @klass.enable
        @klass.forgo { assert !@klass.enabled? }
        assert @klass.enabled?
      end

      should "not change enabled flag if false when called" do
        @klass.forgo { assert !@klass.enabled? }
        assert !@klass.enabled?
      end

      should "not call reset after block" do
        reset = false
        @klass.register { reset = true }
        @klass.forgo {}
        assert !reset
      end

      should "reset and set enabled when exception raised in block and then reraise" do
        @klass.enable
        reset = false
        @klass.register { reset = true }
        assert_raises(RuntimeError) { @klass.forgo { raise "Testing 1 2 3" } }
        assert !reset
        assert @klass.enabled?
      end

    end

  end

end

