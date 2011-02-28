require "#{File.dirname(__FILE__)}/../test_helper"

class RPCMapper::RelationTest < Test::Unit::TestCase
  SINGLE_VALUE_METHODS = [:limit, :offset, :from, :fresh]
  MULTI_VALUE_METHODS = [:select, :group, :order, :joins, :where, :having, :includes]

  context "RPCMapper::Relation class" do
    setup do
      @model = Class.new(RPCMapper::Test::Base)
      @relation = @model.send(:relation)
      @model.class_eval do
        scope :foo, where('foo')
        scope :bar, where('bar')
      end
      @adapter = @model.send(:read_adapter)
    end

    teardown do
      @adapter.reset
    end

    context "merge method" do
      should "push multi-fields onto that value's array" do
        relation = @relation.dup
        MULTI_VALUE_METHODS.each { |method| relation = relation.merge(@relation.send(method, 'foo')) }
        hash = relation.to_hash
        MULTI_VALUE_METHODS.each do |method|
          assert_equal ['foo'], hash[method]
        end
      end

      should "replace single-field values with merge relation's value" do
        relation = @relation.dup
        SINGLE_VALUE_METHODS.each { |method| relation = relation.merge(@relation.send(method, 'foo')) }
        hash = relation.to_hash
        SINGLE_VALUE_METHODS.each do |method|
          assert_equal 'foo', hash[method]
        end
      end

    end

    context "records accessor" do
      setup do
        @records = [@model.new, @model.new]
        @relation.records = @records
      end

      should "allow records to be assigned" do
        assert @relation.respond_to?(:records=)
        assert_equal @records, @relation.to_a
      end

      should "return the value of records through the reader" do
        assert_equal @records, @relation.records
      end

      should "not run a query when records is set" do
        assert_equal @records, @relation.all
        assert !@adapter.last_call
      end

      should "force a query to run with fresh scope even when records is set explicitly" do
        assert_not_equal @records, @relation.fresh.all
        assert @adapter.last_call
      end

    end

    context "to_hash method" do
      setup do
        @all_methods = SINGLE_VALUE_METHODS + MULTI_VALUE_METHODS
        @loaded_relation = @relation.clone
        @all_methods.each { |method| @loaded_relation = @loaded_relation.send(method, 'foo') }
      end

      should "return only :sql key if :sql option is set" do
        hash = @loaded_relation.sql('bar').to_hash
        @all_methods.each { |method| assert_nil hash[method] }
        assert_equal 'bar', hash[:sql]
      end

      should "use all values if :sql option is not set" do
        hash = @loaded_relation.to_hash
        @all_methods.each { |method| assert_equal 'foo', (v = hash[method]).is_a?(Array) ? v.first : v }
        assert_nil hash[:sql]
      end

      should "not include blank values" do
        hash = @relation.where('foo').to_hash
        assert_equal ['foo'], hash[:where]
        assert_equal [:where], hash.keys
      end

      should "call any procs set on value methods to allow delayed execution" do
        @all_methods.each do |method|
          @relation = @relation.send(method, proc { "#{method}_val" })
        end

        hash = @relation.to_hash

        hash.each do |key, value|
          if value.is_a?(Array)
            assert value.inject(true) { |sum, v| sum && !v.is_a?(Proc) }
          else
            assert !value.is_a?(Proc)
          end
        end
      end

      should "remove all select values if one ends in '*'" do
        assert_equal %w(foo), @relation.select('foo').to_hash[:select]
        assert_equal %w(foo *bar), @relation.select('foo').select('*bar').to_hash[:select]
        assert_nil @relation.select('foo').select('*bar').select('baz*').to_hash[:select]
      end
    end

    context "scoping method" do
      setup do
        @relation = @model.foo.bar
      end

      should "impose its scopes on all references to the base model within the block" do
        @relation.scoping do
          assert_equal "foobar", @model.scoped.to_hash[:where].join
        end
      end

      should "remove all scopes when exiting the block successfully" do
        @relation.scoping {}
        assert_nil @model.scoped.to_hash[:where]
      end

      should "remove all scopes when exiting the block with exception raised" do
        assert_raises(RuntimeError) { raise "Exception" }
        assert_nil @model.scoped.to_hash[:where]
      end

      should "function correctly when unscoped block used within the scoping block" do
        @relation.scoping do
          @model.unscoped do
            assert_nil @model.scoped.to_hash[:where]
          end
          assert_equal "foobar", @model.scoped.to_hash[:where].join
        end
        assert_nil @model.scoped.to_hash[:where]
      end
    end

    #-----------------------------------------
    # TRP: Method Delegation
    #-----------------------------------------
    context "dynamic finder methods (find_by_*, etc.)" do
      setup do
        @model.class_eval do
          attributes :name, :age, :weight
        end
      end

      should "fail when attribute does not exist" do
        assert_raise(NoMethodError) { @relation.find_by_height(10) }
      end

      should "not fail when attribute does exist" do
        assert_nothing_raised { @relation.find_by_name('poop') }
      end

      should "be recognized by respond_to?" do
        assert @relation.respond_to?(:find_by_name)
        assert !@relation.respond_to?(:find_by_height)
      end
    end

    should "delegate scope calls to Base" do
      @model.scope :foo, :where => 'foo'
      assert @relation.respond_to?(:foo)
      assert_nothing_raised { @relation.foo }
    end


    #-----------------------------------------
    # TRP: Finder Methods
    #-----------------------------------------
    context "all method" do
      should "accept optional finder options and apply them to the relation" do
        @relation.all(:conditions => 'test')
        assert_equal ['test'], @adapter.last_call.last[:where]
      end

      should "return an array" do
        assert_kind_of Array, @relation.all
      end
    end

    context "first method" do
      should "accept optional finder options and apply them to the relation" do
        @relation.first(:conditions => 'test')
        assert_equal ['test'], @adapter.last_call.last[:where]
      end

      should "return an object or nil if nothing matched" do
        @adapter.data = { :id => 1 }
        assert_kind_of RPCMapper::Base, @relation.first
      end
    end

    context "find method" do
      should "accept string or number as query for the primary_key with finder options" do
        @adapter.data = { :id => 1 }
        @relation.find(1)
        assert_equal [{:id => 1}], @adapter.last_call.last[:where]
        @relation.find("1")
        assert_equal [{:id => 1}], @adapter.last_call.last[:where]
      end

      should "accept array of primary keys with finder options" do
        @adapter.data = { :id => 1 }
        @adapter.count = 4
        @relation.find([1,2,3,4])
        assert_equal [{:id => [1,2,3,4]}], @adapter.last_call.last[:where]
      end

      should "accept :all with finder options" do
        assert_kind_of Array, @relation.find(:all, :conditions => 'test')
        assert_equal ['test'], @adapter.last_call.last[:where]
      end

      should "accept :first with finder options" do
        @adapter.data = { :id => 1 }
        assert_kind_of RPCMapper::Base, @relation.find(:first, :conditions => 'test')
        assert_equal ['test'], @adapter.last_call.last[:where]
      end

      should "raise ArgumentError for wrong usage" do
        assert_raises(ArgumentError) { @relation.find(1.5) }
        assert_raises(ArgumentError) { @relation.find({}) }
      end

      should "raise RPCMapper::RecordNotFound when id passed and record could not be found" do
        assert_raises(RPCMapper::RecordNotFound) { @relation.find(1) }
      end

      should "raise RPCMapper::RecordNotFound when a set of ids is passed and any record could not be found" do
        assert_raises(RPCMapper::RecordNotFound) { @relation.find([1,2,3]) }
      end
    end

    context "fresh method" do
      should "force relation to refetch records if it has already run when true passed" do
        @relation.to_a
        @relation.to_a
        @relation.fresh.to_a
        assert_equal 2, @adapter.calls.size
      end

      should "set fresh_value to true by default" do
        assert !@relation.fresh_value
        @relation = @relation.fresh
        assert @relation.fresh_value
      end

      should "not set fresh_value to true if fresh(false) passed" do
        assert !@relation.fresh_value
        @relation = @relation.fresh(false)
        assert !@relation.fresh_value
      end

      should "not force refetch records when fresh(false) called" do
        @relation.to_a
        @relation.to_a
        @relation.fresh(false).to_a
        assert_equal 1, @adapter.calls.size
      end
    end

    context "search method" do
      # TODO: Pull this code out of this gem and
    end

    context "apply_finder_options method" do
      setup do
        @model.send :attributes, :id
        @all_methods = SINGLE_VALUE_METHODS + MULTI_VALUE_METHODS
      end

      should "allow any of the regular query methods as keys" do
        finder_hash = @all_methods.inject({}) { |hash, method| hash.merge({ method => 'foo' }) }
        hash = @relation.apply_finder_options(finder_hash).to_hash
        @all_methods.each { |method| assert_equal 'foo', (v = hash[method]).is_a?(Array) ? v.first : v }
      end

      should "allow :conditions as alias for :where" do
        assert_equal ['foo'], @relation.apply_finder_options(:conditions => 'foo').to_hash[:where]
      end

      should "allow :sql key and pass through" do
        assert_equal 'foo', @relation.apply_finder_options(:sql => 'foo').to_hash[:sql]
      end

      should "allow :include key as alias for :includes" do
        assert_equal ['foo'], @relation.apply_finder_options(:include => 'foo').to_hash[:includes]
      end

      should "allow :search key and pass through to search method" do
        assert_equal [{"id_equals" => 1}], @relation.apply_finder_options(:search => { :id_is => 1}).to_hash[:where]
      end
    end


    #-----------------------------------------
    # TRP: Query Methods
    #-----------------------------------------
    context "select query method" do
      should "delegate to array if block is passed" do
        assert_kind_of(RPCMapper::Relation, @relation.select('foo'))
        assert_kind_of(Array, @relation.select {})
      end
    end

    # Multi query methods
    MULTI_VALUE_METHODS.each do |method|
      context "#{method} query method" do
        should "clone new relation and append value to #{method}_values" do
          new_relation = @relation.send(method, 'foo')
          assert_equal [], @relation.send("#{method}_values")
          assert_equal ['foo'], new_relation.send("#{method}_values")
        end
      end
    end

    # Single query methods
    SINGLE_VALUE_METHODS.each do |method|
      context "#{method} query method" do
        should "clone new relation and replace value in #{method}_value" do
          new_relation = @relation.send(method, 'foo')
          assert_nil @relation.send("#{method}_value")
          assert_equal 'foo', new_relation.send("#{method}_value")
        end
      end
    end

    # SQL query method
    context "sql query method" do
      should "clone new relation and replace the raw_sql_value" do
        new_relation = @relation.sql('select * from foo')
        assert_nil @relation.raw_sql_value
        assert_equal 'select * from foo', new_relation.raw_sql_value
      end
    end


  end

end
