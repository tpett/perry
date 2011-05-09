require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::AbstractAdapterTest < Test::Unit::TestCase

  context "AbstractAdapter class" do

    setup do
      @abstract = Perry::Adapters::AbstractAdapter
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

      should "call stack items in order: processors, object builder, middlewares" do
        Perry::Test::FakeAdapterStackItem.reset
        class MiddlewareA < Perry::Test::FakeAdapterStackItem; end
        class MiddlewareB < Perry::Test::FakeAdapterStackItem; end
        class ProcessorA < Perry::Test::FakeAdapterStackItem; end
        class ProcessorB < Perry::Test::FakeAdapterStackItem; end

        class Foo < @abstract
          register_as :foo

          def read(options)
            Perry::Test::FakeAdapterStackItem.log << ["read", options]
            [ { :id => 1 } ]
          end
        end

        config = proc do |config|
          config.add_middleware(MiddlewareA, :foo => 'A')
          config.add_processor(ProcessorA, :bar => 'A')
        end

        config2 = proc do |config|
          config.add_middleware(MiddlewareB, :foo => 'B')
          config.add_processor(ProcessorB, :bar => 'B')
        end

        adapter = Foo.new(:foo, config)
        adapter = adapter.extend_adapter(config2)

        relation = Perry::Test::Blog::Site.scoped
        adapter.call('read', { :relation => relation })

        correct = [
          [ "ProcessorA", { :bar => 'A' }, { :relation => relation } ],
          [ "ProcessorB", { :bar => 'B' }, { :relation => relation } ],
          [ "MiddlewareA", { :foo => 'A' }, { :relation => relation } ],
          [ "MiddlewareB", { :foo => 'B' }, { :relation => relation } ],
          [ "read", { :relation => relation } ],
          [ Hash ],
          [ Hash ],
          [ Perry::Test::Blog::Site ],
          [ Perry::Test::Blog::Site ],
        ]

        assert_equal(correct, Perry::Test::FakeAdapterStackItem.log)

        adapter.call('read', { :relation => relation })

        assert_equal(correct + correct, Perry::Test::FakeAdapterStackItem.log)
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
      @config = Perry::Adapters::AbstractAdapter::AdapterConfig
    end

    should "have functionality of OpenStruct" do
      assert @config.ancestors.include?(OpenStruct)
    end

    context "add_middleware instance method" do

      should "take 2 parameters with the second optional" do
        assert_equal -2, @config.instance_method(:add_middleware).arity
      end

      should "push value on array in :middlwares value on marshal" do
        conf = @config.new
        conf.add_middleware('Value')
        assert_equal({ :middlewares => [['Value', {}]] }, conf.marshal_dump)
      end

    end

    context "add_processor instance method" do
      should "take 2 parameters with the second being optional" do
        method = @config.instance_method(:add_processor)
        assert method
        assert_equal -2, method.arity
      end

      should "push value on array in :processors value on marshal" do
        config = @config.new
        config.add_processor('Poop', :foo => :bar)
        assert_equal({ :processors => [['Poop', { :foo => :bar }]] }, config.to_hash)
      end
    end

    context "to_hash instance method" do

      should "return the marshal dump" do
        conf = @config.new(:foo => :bar)
        assert_equal({ :foo => :bar }, conf.to_hash)
      end

    end

  end

  context "ModelBuilder class" do
    setup do
      @builder = Perry::Adapters::AbstractAdapter::ModelBuilder

      class FakeAdapter
        def call(options)
          [ { :id => 1 } ]
        end
      end

      @stack = @builder.new(FakeAdapter.new)
      @relation = Perry::Test::Blog::Site.scoped
    end

    should "have a initialize method and call method" do
      assert_equal -2, @builder.instance_method(:initialize).arity
      assert_equal 1, @builder.instance_method(:call).arity
    end

    should "call rest of stack and initialize the returned records if query options contains :relation" do
      result = @stack.call(:relation => @relation)
      assert_equal 1, result.size
      assert_equal @relation.klass, result.first.class
    end

    should "set new_record? to false on new records" do
      result = @stack.call(:relation => @relation)
      assert !result.first.new_record?
    end

    should "be no-op if does not contain :relation" do
      result = @stack.call({})
      assert_equal [ { :id => 1 } ], result
    end

  end

end

