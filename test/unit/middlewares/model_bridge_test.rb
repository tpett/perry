require "#{File.dirname(__FILE__)}/../../test_helper"

class Perry::Middlewares::ModelBridgeTest < Test::Unit::TestCase

  context "ModelBridge class" do
    setup do
      @bridge = Perry::Middlewares::ModelBridge
    end

    context "when query mode is :read" do
      setup do
        class FakeAdapter
          def call(options)
            [ { :id => 1 } ]
          end
        end

        @stack = @bridge.new(FakeAdapter.new)
        @relation = Perry::Test::Blog::Site.scoped
        @options = { :relation => @relation, :mode => :read }
      end

      should "call rest of stack and initialize the returned records" do
        result = @stack.call(@options)
        assert_equal 1, result.size
        assert_equal @relation.klass, result.first.class
      end

      should "set new_record? to false on new records" do
        result = @stack.call(@options)
        assert !result.first.new_record?
      end

      should "be no-op if does not contain :relation" do
        @options.delete(:relation)
        result = @stack.call(@options)
        assert_equal [ { :id => 1 } ], result
      end
    end

    context "when query mode is :write" do
      setup do
        class SuccessAdapter
          def response
            @response ||= Perry::Persistence::Response.new({
              :success => true,
              :parsed => { :id => 1 }
            })
          end
          def call(options)
            response
          end
        end

        class FailureAdapter
          def response
            @response ||= Perry::Persistence::Response.new({
              :success => false,
              :parsed => { 'base' => "record invalid", "name" => "can't be blank" }
            })
          end
          def call(options)
            response
          end
        end

        @klass = Class.new(Perry::Test::SimpleModel)
        @model = @klass.new
        @model.new_record = nil
        @model.saved = nil
        @model.read_adapter.data = { :id => 1 }
        @options = { :object => @model, :mode => :write }
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

        should "raise if Response does not have a value for the model's primary key in the Response#model_attributes collection" do
          assert_raise Perry::PerryError do
            adapter = SuccessAdapter.new
            adapter.response.parsed = nil
            @bridge.new(adapter).call(@options)
          end
        end
      end

      should "set the model's :saved attribute to true on success" do
        @bridge.new(SuccessAdapter.new).call(@options)
        assert_equal true, @model.saved?
      end

      should "set the model's :saved attribute to false on failure" do
        @bridge.new(FailureAdapter.new).call(@options)
        assert_equal false, @model.saved?
      end

      should "reload the model on success" do
        @bridge.new(SuccessAdapter.new).call(@options)
        assert_equal 1, @model.read_adapter.calls.size
      end

      should "not reload the model on failure" do
        @bridge.new(FailureAdapter.new).call(@options)
        assert_equal 0, @model.read_adapter.calls.size
      end

      should "add error messages to the model on failure" do
        @bridge.new(FailureAdapter.new).call(@options)
        assert_equal 'record invalid', @model.errors[:base]
        assert_equal "can't be blank", @model.errors[:name]
      end

      should "add error messages to the model on failure even if Response#errors has no errors" do
        adapter = FailureAdapter.new
        adapter.response.parsed = nil
        @bridge.new(adapter).call(@options)
        assert_equal 1, @model.errors.length
      end

      should "not reload the model if a read_adapter is not present" do
        klass = Class.new(Perry::Test::SimpleModel)
        klass.read_adapter = nil
        def klass.fetch_records(relation)
          raise "read_adapter is not present"
        end

        model = klass.new
        model.new_record = nil
        model.saved = nil
        options = { :object => model, :mode => :write }

        assert_nothing_raised do
          @bridge.new(SuccessAdapter.new).call(options)
        end
      end
    end

    context "when query mode is :delete" do
      setup do
        class SuccessAdapter
          def call(options)
            Perry::Persistence::Response.new(:success => true)
          end
        end

        class FailureAdapter
          def response
            @response ||= Perry::Persistence::Response.new({
              :success => false,
              :parsed => { 'base' => 'record does not exist' }
            })
          end
          def call(options)
            response
          end
        end

        @klass = Class.new(Perry::Test::SimpleModel)
        @model = @klass.new
        @model.new_record = false
        @options = { :object => @model, :mode => :delete }
      end

      should "freeze! the model on success" do
        @bridge.new(SuccessAdapter.new).call(@options)
        assert @model.frozen?, "expected model to be frozen"
        assert !@model.attributes.frozen?, "expected attributes to not be frozen"
      end

      should "not freeze the model on failure" do
        @bridge.new(FailureAdapter.new).call(@options)
        assert !@model.frozen?, "expected model to not be frozen"
      end

      should "add error messages to the model on failure" do
        @bridge.new(FailureAdapter.new).call(@options)
        assert_equal 'record does not exist', @model.errors[:base]
      end

      should "add a default error message to the model on failure if Response#errors has no errors" do
        adapter = FailureAdapter.new
        adapter.response.parsed = nil
        @bridge.new(adapter).call(@options)
        assert_equal 'not deleted', @model.errors[:base]
      end
    end

  end

end
