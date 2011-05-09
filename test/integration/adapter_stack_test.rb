require "#{File.dirname(__FILE__)}/../test_helper"


class Perry::AdapterStackTest < Test::Unit::TestCase

  context "model with middlewares and adapters configured" do
    setup do
      Perry::Test::FakeAdapterStackItem.reset
      class MiddlewareA < Perry::Test::FakeAdapterStackItem; end
      class ProcessorA < Perry::Test::FakeAdapterStackItem; end

      @model = Class.new(Perry::Test::Base)
      @model.class_eval do
        configure_read do |config|
          config.add_middleware MiddlewareA
          config.add_processor ProcessorA
        end

        write_with :test

        configure_write do |config|
          config.add_processor ProcessorA
          config.add_middleware MiddlewareA
        end
      end
      @adapter = @model.read_adapter
    end

    should "hit the whole adapter stack with any query" do
      @adapter.data = { :id => 1 }
      relation = @model.where(:id => 1)
      result = relation.to_a

      correct = [
        [ 'ProcessorA', {}, { :relation => relation } ],
        [ 'MiddlewareA', {}, { :relation => relation } ],
        [ Hash ],
        [ @model ]
      ]

      assert_equal correct, Perry::Test::FakeAdapterStackItem.log
      assert !result.first.new_record?
    end

    should "hit the whole adapter stack with any save" do
      object = @model.new
      object.save

      correct = [
        [ 'ProcessorA', {}, { :object => object } ],
        [ 'MiddlewareA', {}, { :object => object } ],
      ]

      assert_equal correct, Perry::Test::FakeAdapterStackItem.log[0..1]
    end

    should "hit the whole adapter stack with any delete" do
      object = @model.new_from_data_store({})
      object.delete

      correct = [
        [ 'ProcessorA', {}, { :object => object } ],
        [ 'MiddlewareA', {}, { :object => object } ],
      ]

      assert_equal correct, Perry::Test::FakeAdapterStackItem.log[0..1]
    end
  end

end

