require "#{File.dirname(__FILE__)}/../test_helper"

class RPCMapper::AbstractAdapterTest < Test::Unit::TestCase

  context "AbstractAdapter class" do

    setup do
      @abstract = RPCMapper::Adapters::AbstractAdapter
    end

    context "initialize method" do

      should "take two parameters" do
        assert_equal 2, @abstract.instance_method('initialize').arity
      end

      should "set the first to @type and the second to @configuration_contexts" do
        adapter = @abstract.new(:foo, ['foo'])
        assert_equal :foo, adapter.send(:instance_variable_get, :@type)
        assert_equal ['foo'], adapter.send(:instance_variable_get, :@configuration_contexts)
      end

      should "ensure @configuration_contexts is an array" do
        adapter = @abstract.new(:foo, 'bar')
        assert_equal ['bar'], adapter.send(:instance_variable_get, :@configuration_contexts)
      end

      should "set @type to a symbol" do
        adapter = @abstract.new('foo', 'bar')
        assert_equal :foo, adapter.send(:instance_variable_get, :@type)
      end

    end

    context "register_as class method" do
      should "register the calling class in @@registered_adapters" do
        class Foo < @abstract
          register_as 'foo'
        end
        class_var = @abstract.send(:class_variable_get, :@@registered_adapters)
        assert_equal Foo, class_var[:foo]
        class_var.delete(:foo)
      end
    end

    context "create class method" do
      setup do
        class Foo < @abstract
          register_as :foo
        end
        @foo = Foo
      end

      teardown do
        @abstract.send(:class_variable_get, :@@registered_adapters).delete(:foo)
      end

      should "use the specified type's class" do
        assert_equal @foo, @abstract.create(:foo, {}).class
      end

      should "pass configuration to init method" do
        adapter = @abstract.create(:foo, { :bar => :baz })
        assert_equal :baz, adapter.config[:bar]
      end
    end

    context "call instnace method" do

      should "take two arguments" do
        assert_equal 2, @abstract.instance_method('call').arity
      end

      should "call each middleware in order followed by the mode method" do
        class FakeMiddleware
          @@output = []
          def initialize(adapter, config={})
            @adapter = adapter
            @config = config
          end

          def call(options)
            @@output << [self.class.name.split('::').last, @config, options]
            @adapter.call(options)
          end

          def self.log(msg=nil)
            if msg
              @@output << log
            else
              @@output
            end
          end
        end
        class MiddlewareA < FakeMiddleware; end
        class MiddlewareB < FakeMiddleware; end

        class Foo < @abstract
          register_as :foo

          def read(options)
            FakeMiddleware.log << ["read", options]
            []
          end
        end

        config = proc do |config|
          config.add_middleware(MiddlewareA, :foo => 'A')
          config.add_middleware(MiddlewareB, :foo => 'B')
        end

        adapter = Foo.new(:foo, config)

        adapter.call('read', { :object => 'Baz'})

        correct = [
          [ "MiddlewareA", { :foo => 'A' }, { :object => 'Baz' } ],
          [ "MiddlewareB", { :foo => 'B' }, { :object => 'Baz' } ],
          [ "read", { :object => 'Baz'} ]
        ]

        assert_equal(correct, FakeMiddleware.log)

        adapter.call('read', { :object => 'Baz'})

        assert_equal(correct + correct, FakeMiddleware.log)
      end

    end

    context "configuration in hash or AdapterConfig" do
      setup do
        class Foo < @abstract
          register_as :foo
        end
        @foo = Foo
      end

      should "merge from instances chained with extend_adapter" do
        adapter = @abstract.create(:foo, :foo => 'bar')
        assert_equal 'bar', adapter.config[:foo]

        adapter = adapter.extend_adapter(:foo => 'baz')
        assert_equal 'baz', adapter.config[:foo]

        adapter = adapter.extend_adapter(proc { |conf| conf.foo = 'poo' })
        assert_equal 'poo', adapter.config[:foo]
      end

      should "append middlewares added on each adapter extension" do
        adapter = @abstract.create(:foo, {})

        adapter = adapter.extend_adapter(proc { |conf| conf.add_middleware('foo') })
        assert_equal [['foo', {}]], adapter.config[:middlewares]

        adapter = adapter.extend_adapter(proc { |conf| conf.add_middleware('bar', :baz => :poo) })
        assert_equal [['foo', {}], ['bar', {:baz => :poo}]], adapter.config[:middlewares]

        adapter = adapter.extend_adapter(proc { |conf| conf.add_middleware('baz') })
        assert_equal [['foo', {}], ['bar', {:baz => :poo}], ['baz', {}]],
            adapter.config[:middlewares]
      end
    end

  end

  context "AdapterConfig class" do
    setup do
      @config = RPCMapper::Adapters::AbstractAdapter::AdapterConfig
    end

    should "have functionality of OpenStruct" do
      assert @config.ancestors.include?(OpenStruct)
    end

    context "add_middleware instance method" do

      should "take 2 parameters with the second optional" do
        assert_equal -2, @config.instance_method(:add_middleware).arity
      end

      should "push value on array in :middlware value on marshal" do
        conf = @config.new
        conf.add_middleware('Value')
        assert_equal({ :middlewares => [['Value', {}]] }, conf.marshal_dump)
      end

    end

    context "to_hash instance method" do

      should "return the marshal dump" do
        conf = @config.new(:foo => :bar)
        assert_equal({ :foo => :bar }, conf.to_hash)
      end

    end

  end

end

