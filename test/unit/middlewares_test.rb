require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::MiddlewaresTest < Test::Unit::TestCase
  context "middlewares" do
    should "define a Middlewares module" do
      assert Perry.const_defined?(:Middlewares)
    end
  end

  # Check that each middleware class conforms to the middleware #call interface
  AVAILABLE_MIDDLEWARES = [:CacheRecords, :ModelBridge]
  AVAILABLE_MIDDLEWARES.each do |middleware_class|
    context "#{middleware_class} middleware" do
      setup do
        @klass = Class.new(Perry::Test::SimpleModel)
        @adapter_class = Perry::Test::MiddlewareAdapter
        @middleware_class = Perry::Middlewares.const_get(middleware_class)
        @middleware = @middleware_class.new(@adapter_class.new(:read, {}))
      end

      should "respond to call" do
        assert @middleware.respond_to?(:call)
      end

      context "initialize method" do
        should "accept one argument and an optional argument" do
          assert_equal -2, @middleware.method(:initialize).arity
        end
      end

      context "call method" do
        should "accept one argument" do
          assert_equal 1, @middleware.method(:call).arity
        end

        should "return an array-like object on reads" do
          options = { :relation => @klass.send(:relation), :mode => :read }
          assert @middleware.call(options).respond_to?(:collect)
        end

        should "return a Response object on writes" do
          write_adapter = @adapter_class.new(:write, {})
          middleware = @middleware_class.new(write_adapter)
          options = { :object => @klass.new, :mode => :write }
          options[:object].read_adapter = nil
          assert middleware.call(options).is_a?(Perry::Persistence::Response)
        end

        should "return a Response object on deletes" do
          delete_adapter = @adapter_class.new(:delete, {})
          middleware = @middleware_class.new(delete_adapter)
          options = { :object => @klass.new, :mode => :delete }
          assert middleware.call(options).is_a?(Perry::Persistence::Response)
        end
      end
    end
  end

end
