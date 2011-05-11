require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::Persistence::ResponseTest < Test::Unit::TestCase

  RESPONSE_ATTRIBUTES = [:success, :status, :meta, :raw, :raw_format, :parsed]

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

    should "have class attribute :parsers" do
      model = Perry::Persistence::Response
      assert model.respond_to?(:parsers)
      assert_equal Hash, model.parsers.class
      assert model.parsers.has_key?(:json)
    end

    context "parsed method" do
      should "be an instance method" do
        assert @response.respond_to?(:parsed)
      end

      should "parse JSON if raw_format is :json, cache it, and return it" do
        json = %({ "foo": 123, "bar": ["a", "b", { "c": "baz" }] })
        ruby = { "foo" => 123, "bar" => ["a", "b", { "c" => "baz" }] }

        @response.raw = json
        @response.raw_format = :json

        assert_equal ruby, @response.parsed
        assert_equal ruby, @response.send(:instance_variable_get, :@parsed)
      end

      should "return nil for unknown raw_format" do
        @response.raw = "foo foo foo"
        @response.raw_format = :foobar

        assert_nil @response.parsed
      end
    end

    context "model_attributes method" do
      should "be an instance method" do
        assert @response.respond_to?(:model_attributes)
      end
      should "return the attributes hash from parsed response if present" do
        {
          # Single item hash with non-hash value
          { :foo => 'bar' } => { :foo => 'bar' },
          # Single item hash with nested single item hash
          { :foo => { :bar => 'baz' } } => { :bar => 'baz' },
          # Multi item hash with nested hash
          { :foo => 1, :bar => { :baz => 1 } } => { :foo => 1, :bar => { :baz => 1 } },
          # Single item hash with nested multi item hash
          { :foo => { :bar => 1, :baz => 2 } } => { :bar => 1, :baz => 2 },
          # Nested hash with string keys converts to symbols
          { 'foo' => { 'bar' => 1, 'baz' => 2 } } => { :bar => 1, :baz => 2 },
          # Bad responses
          [1, 2, 3] => {},
          'abc' => {}
        }.each do |input, output|
          @response.parsed = input
          assert_equal output, @response.model_attributes
        end
        @response.parsed = { :foo => 'bar', :bar => 'foo' }

      end

      should "return empty hash if not present" do
        assert_equal({}, @response.model_attributes)
      end
    end

    context "errors method" do
      should "be a instance method" do
        assert @response.respond_to?(:errors)
      end

      should "return the errors hash from parsed response if present" do
        {
          # Hash of values
          { :foo => 'bar', :bar => 'baz' } => { :foo => 'bar', :bar => 'baz' },
          # Should symbolize keys
          { 'foo' => 'bar' } => { :foo => 'bar' },
          # Bad responses
          ['foo', 'bar', 'baz'] => {},
          1 => {}
        }.each do |input, output|
          @response.parsed = input
          assert_equal output, @response.errors
        end
      end
      should "return empty hash if not present"
    end

  end
end

