require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::PersistenceTest < Test::Unit::TestCase

  context "Perry::Persistence" do
    setup do
      @model = Class.new(Perry::Test::SimpleModel)
      @adapter = @model.send(:read_adapter)
      # TRP: Block all Net::HTTP requests
      FakeWeb.allow_net_connect = false

      @model.class_eval do
        attributes :a, :b, :c
        write_with :test

        configure_write do |config|
          config.post_body_wrapper = "test"
        end
      end
      @model.read_adapter.data = { :id => 1 }
      @object = @model.new
    end

    teardown do
      @adapter.reset
    end

    should "require perry/persistence if needed" do
      assert defined?(Perry::Persistence)
    end

    should "include Perry::Persistence module" do
      assert @model.ancestors.include?(Perry::Persistence)
    end

    should "define persistence state methods on base" do
      [:new_record, :new_record?, :saved, :saved?, :persisted?, :new_record=, :saved=].each do |method|
        assert_respond_to(@object, method)
      end
    end

    should "define writers for attributes that have been declared" do
      instance = @model.new
      assert instance.respond_to?(:a=)
      assert instance.respond_to?(:b=)
      assert instance.respond_to?(:c=)
    end

    should "set config options to adapter config" do
      assert @model.write_adapter.config.keys.include?(:post_body_wrapper)
    end

    should "call write method on the write_adapter when save called" do
      assert @object.save
      assert_equal @object, @model.write_adapter.last_write.last
    end

    should "call delete method on the write_adapter when delete called" do
      @object.new_record = false
      assert @object.delete
      assert_equal @object, @model.write_adapter.last_call.last
    end

    should "not call delete method on the write adapter when new_record? is true" do
      assert !@object.delete
      assert !@model.write_adapter.last_call
    end

    should "set attribtues and save on update_attributes" do
      obj = @model.new_from_data_store(:a => 'a', :b => 'b')
      assert obj.update_attributes(:b => 'c')
      assert_equal obj, @model.write_adapter.last_write.last
      assert_equal 'a', obj.a
      assert_equal 'c', obj.b
    end

    should "raise exception if save! or update_attributes! called and failed" do
      @object.write_adapter.writes_return false
      assert_raises(Perry::RecordNotSaved) { @object.save! }
      assert_raises(Perry::RecordNotSaved) { @object.update_attributes!({}) }
    end

    should "fetch object from database when calling #reload" do
      @object.read_adapter.data = { "a" => "foo" }
      @object.a = 'blah'
      attrs_before = @object.attributes.clone
      @object.reload
      assert_not_equal attrs_before, @object.attributes
    end

    should "define a #freeze! method to set the @frozen instance variable" do
      assert_nil @object.instance_variable_get(:@frozen)
      @object.freeze!
      assert @object.instance_variable_get(:@frozen)
    end

    should "override the #frozen? method to return the value of @frozen" do
      assert !@object.frozen?
      @object.freeze!
      assert @object.frozen?
    end

    should "override Object#freeze to also call #freeze!" do
      assert !@object.frozen?
      @object.freeze
      assert @object.frozen?
      assert @object.instance_variable_get(:@frozen)
    end

    should "freeze the attributes hash on #freeze but not #freeze!" do
      @object.freeze!
      assert_nothing_raised { @object.a = 'b' }
      @object.freeze
      assert_raise(TypeError) { @object.b = 'c' }
    end

    should "raise on save if object is frozen" do
      @object.freeze
      assert_raise Perry::PerryError do
        @object.save
      end
      assert @object.write_adapter.calls.empty?
    end

    should "raise on destroy if object is frozen" do
      @object.freeze
      assert_raise Perry::PerryError do
        @object.destroy
      end
      assert @object.write_adapter.calls.empty?
    end
  end

end
