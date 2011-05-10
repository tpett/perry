require "#{File.dirname(__FILE__)}/../../test_helper"

class Perry::Middlewares::ModelBridgeTest < Test::Unit::TestCase

  context "ModelBridge class" do
    setup do
      @bridge = Perry::Middlewares::ModelBridge
    end

    context "on reads" do
      setup do
        class FakeAdapter
          def call(options)
            [ { :id => 1 } ]
          end
        end

        @stack = @bridge.new(FakeAdapter.new)
        @relation = Perry::Test::Blog::Site.scoped
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

    context "on writes" do
      setup do
        class SuccessAdapter
          def call(options)
            Perry::Persistence::Response.new({
              :success => true,
              :model_attributes => { :id => 1 }
            })
          end
        end

        class FailureAdapter
          def call(options)
            Perry::Persistence::Response.new({
              :success => false,
              :errors => ["record invalid", ["name", "can't be blank"]]
            })
          end
        end

        @klass = Class.new(Perry::Test::SimpleModel)
        @model = @klass.new
        @model.new_record = nil
        @model.saved = nil
        @options = { :object => @model }
      end

      teardown do
        @model.read_adapter.reset
        @model.write_adapter.reset
      end

      context "for new records" do
        setup do
          @model.new_record = true
        end

        should "set the model's primary_key attribute on success" do
          assert_nil @model.id
          @bridge.new(SuccessAdapter.new).call(@options)
          assert_equal 1, @model.id
        end

        should "keep the model's :new_record attribute as true on failure" do
          @bridge.new(FailureAdapter.new).call(@options)
          assert_equal true, @model.new_record?
        end

        should "set the model's :new_record attribute to false on success" do
          @bridge.new(SuccessAdapter.new).call(@options)
          assert_equal false, @model.new_record?
        end

        should "raise if Response does not have a value for the model's primary key in the Response#model_attributes collection"
      end

      should "set the model's :saved attribute to true on success" do
        @bridge.new(SuccessAdapter.new).call(@options)
        assert_equal true, @model.saved?
      end

      should "set the model's :saved attribute to false on failure" do
        @bridge.new(FailureAdapter.new).call(@options)
        assert_equal false, @model.saved?
      end

      should_eventually "reload the model on success" do
        @bridge.new(SuccessAdapter.new).call(@options)
        assert_equal 1, @model.read_adapter.calls.size
      end
      should "not reload the model on failure" do

      end

      should "add error messages to the model on failure"
      should "add error messages to the model on failure even if Response#errors is nil"
    end

  end

end
