require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::MiddlewaresTest < Test::Unit::TestCase
  context "middlewares" do
    should "define a Middlewares module" do
      assert Perry.const_defined?(:Middlewares)
    end
  end

  # Check that each middleware class conforms to the middleware #call interface
  AVAILABLE_MIDDLEWARES = [:CacheRecords]
  AVAILABLE_MIDDLEWARES.each do |middleware_class|
    context "#{middleware_class} middleware" do
      setup do
        @options = {}
        @adapter = Perry::Test::MiddlewareAdapter.new(:read, {})
        @klass = Perry::Middlewares.const_get(middleware_class)
        @middleware = @klass.new(@adapter)
      end

      should "respond to call" do
        assert @middleware.respond_to?(:call)
      end

      context "call method" do
        should "accept one argument" do
          assert_equal 1, @middleware.method(:call).arity
        end

        should "return an array-like object" do
          assert @middleware.call(@options).respond_to?(:collect)
        end
      end
    end
  end

end
