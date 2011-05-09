require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::ResponseTest < Test::Unit::TestCase
  context "Perry::Persistance::Response" do
    setup do
      @response = Perry::Persistence::Response.new
    end

    RESPONSE_ATTRIBUTES = [:success, :status, :meta, :raw, :format, :model_attributes, :errors]
    RESPONSE_ATTRIBUTES.each do |attr|
      should "define a reader for the #{attr} attribute" do
        assert @response.respond_to?(attr)
      end
      should "define a writer for the #{attr} attribute" do
        assert @response.respond_to?("#{attr}=")
      end
    end
  end
end
