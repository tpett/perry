require "#{File.dirname(__FILE__)}/../../test_helper"

class Perry::Middlewares::ModelBridgeTest < Test::Unit::TestCase

  context "ModelBridge class" do

    context "on reads" do
      setup do
        @bridge = Perry::Middlewares::ModelBridge

        class FakeAdapter
          def call(options)
            [ { :id => 1 } ]
          end
        end

        @stack = @bridge.new(FakeAdapter.new)
        @relation = Perry::Test::Blog::Site.scoped
      end

      should "have a initialize method and call method" do
        assert_equal -2, @bridge.instance_method(:initialize).arity
        assert_equal 1, @bridge.instance_method(:call).arity
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

end
