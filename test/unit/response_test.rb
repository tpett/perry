require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::ResponseTest < Test::Unit::TestCase

  RESPONSE_ATTRIBUTES = Perry::Persistence::Response::ATTRIBUTES

  context "Perry::Persistance::Response" do
    setup do
      @response = Perry::Persistence::Response.new
    end

    RESPONSE_ATTRIBUTES.each do |attr|
      should "define a reader for the #{attr} attribute" do
        assert @response.respond_to?(attr)
      end
      should "define a writer for the #{attr} attribute" do
        assert @response.respond_to?("#{attr}=")
      end
    end

    should "assign attributes in initializer" do
      attrs = RESPONSE_ATTRIBUTES.inject({}) { |hash, attr| hash.merge(attr => :foo) }
      response = @response.class.new(attrs)

      attrs.each do |attr_name, attr_value|
        assert_equal attr_value, response.send(attr_name)
      end
    end
  end
end
