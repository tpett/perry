require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::BaseTest < Test::Unit::TestCase

  context "Perry::Base class" do
    setup do
      @model = Class.new(Perry::Test::Base)
      @adapter = @model.send(:read_adapter)
      # TRP: Block all Net::HTTP requests
      FakeWeb.allow_net_connect = false
    end

    teardown do
      @adapter.reset
    end

    #-----------------------------------------
    # TRP: Configuration methods
    #-----------------------------------------
    context "config_options" do
      setup do
        @model.class_eval do
          configure_read do |config|
            config.service = "models"
            config.namespace = @foo
          end
        end
      end

      should "set value if passed" do
        assert_equal "models", @model.read_adapter.config[:service]
      end

      should "set value to passed proc (when a proc) and delay execution to next read of that variable" do
        @model.send(:instance_variable_set, :@foo, "bar")
        assert_equal "bar", @model.read_adapter.config[:namespace]
      end
    end

    # TRP: new_record flag control
    should "set new_record true when a new object is created directly" do
      assert @model.new.new_record?
    end

    context "new_from_data_store method" do
      setup do
        @attributes = Factory(:widget)
        @widget = Perry::Test::Warehouse::Widget.new_from_data_store(@attributes)
      end

      should "instantiate a new object from hash" do
        @attributes.each do |attr, value|
          assert_equal value, @widget.send(attr)
        end
      end

      should "set new_record to false" do
        assert !@widget.new_record?
      end

      should "return nil when nil is passed in" do
        assert_nil Perry::Test::Warehouse::Widget.new_from_data_store(nil)
      end
    end

    context "errors method" do
      should "be defined" do
        assert @model.new.respond_to?(:errors)
      end

      should "be readonly" do
        assert !@model.new.respond_to?(:errors=)
      end

      should "default to an empty hash" do
        assert_equal({}, @model.new.errors)
      end

      should "support adding error messages" do
        m = @model.new
        m.errors[:field] = 'error!'
        assert_equal 'error!', m.errors[:field]
      end
    end

    # context "add_processor class method" do
    #   setup do
    #     @processor = Class.new
    #   end

    #   should "accept a class and optional config options" do
    #     method = @model.method(:add_processor)
    #     assert method
    #     assert_equal -2, method.arity
    #   end

    #   should "add to list of processors" do
    #     @model.send(:add_processor, @processor, { :foo => :bar })
    #     processors = @model.send(:class_variable_get, :@@processors)
    #     assert_equal [@processor, { :foo => :bar }], processors.last
    #   end
    # end

    #-----------------------------------------
    # TRP: Scopes
    #-----------------------------------------
    context "scope method" do

      context "with finder options" do
        setup do
          @model.scope :foo, :conditions => "bar"
        end
        should "accept hash of options" do
          assert_equal "bar", @model.foo.to_hash[:where].join
        end
      end

      context "with relation param" do
        setup do
          @model.class_eval do
            scope :foo, where("bar")
          end
        end

        should "accept relation object" do
          assert_equal "bar", @model.foo.to_hash[:where].join
        end
      end

      context "with block" do
        setup do
          @model.class_eval do
            scope :foo, lambda { |bar| where(bar) }
          end
        end

        should "pass parameters from scope call thru to scope method" do
          assert_equal "foobar", @model.foo("foobar").to_hash[:where].join
        end
      end

      should "create method with name of scope" do
        @model.scope :foo, :where => 'bar'
        assert @model.respond_to? :foo
      end

    end

    context "default_scope method" do

      should "merge scopes when called more than once" do
        @model.class_eval do
          default_scope where('foo').limit(2)
          default_scope where('bar').limit(1)
        end
        assert_equal "foobar", @model.scoped.to_hash[:where].join
        assert_equal 1, @model.scoped.to_hash[:limit]
      end

    end

    context "unscoped method" do
      setup do
        @condition = "name = 'bob'"
        @model.send(:default_scope, :conditions => @condition)
      end

      should "remove all scopes for passed block" do
        assert_equal @condition, @model.scoped.to_hash[:where].first

        @model.unscoped do
          assert_nil @model.scoped.to_hash[:where]
        end
      end

      should "restore all scopes when block exits normally" do
        @model.unscoped {}
        assert_equal @condition, @model.scoped.to_hash[:where].first
      end

      should "restore all scopes when block raises an unhandled exception" do
        assert_raise(RuntimeError) do
          @model.unscoped { raise "Exception" }
        end
        assert_equal @condition, @model.scoped.to_hash[:where].first
      end

    end

    COMPARISON_COND = Perry::Scopes::Conditions::COMPARISON_CONDITIONS
    WILDCARD_COND   = Perry::Scopes::Conditions::WILDCARD_CONDITIONS
    context "dynamic condition scopes" do
      setup do
        @model.send :attributes, :a, :b, :c
      end

      # TRP: Check all comparison conditions including aliases
      MERGED_COND = COMPARISON_COND.merge(WILDCARD_COND)
      MERGED_COND.to_a.flatten.each do |method|
        context "#{method} method" do
          should "respond_to? a_#{method}" do
            assert @model.respond_to?("a_#{method}")
          end

          should "not respond_to? d_#{method}" do
            assert !@model.respond_to?("d_#{method}")
          end

          should "return a relation when a_#{method} called" do
            assert_kind_of Perry::Relation, @model.send("a_#{method}", 'foo')
          end

          should "set a where condition for a_#{method}" do
            rel = @model.send("a_#{method}", 'foo')
            full_method_name = method
            if !MERGED_COND.keys.include?(full_method_name)
              MERGED_COND.each { |k,v| full_method_name = k if v.include?(full_method_name) }
            end
            assert_equal 'foo', rel.to_hash[:where].first["a_#{full_method_name}"]
          end

          should "raise NoMethodError for d_#{method} call" do
            assert_raises(NoMethodError) { @model.send("d_#{method}", 'foo') }
          end
        end
      end

    end


    #-----------------------------------------
    # TRP: Dynamic methods
    #-----------------------------------------
    context "dynamic finder methods (find_by_*, etc.)" do
      setup do
        @model.class_eval do
          attributes :name, :age, :weight
        end
      end

      should "fail when attribute does not exist" do
        assert_raise(NoMethodError) { @model.find_by_height(10) }
      end

      should "not fail when attribute does exist" do
        assert_nothing_raised { @model.find_by_name('poop') }
      end

      should "be recognized by respond_to?" do
        assert @model.respond_to?(:find_by_name)
        assert !@model.respond_to?(:find_by_height)
      end
    end


    #-----------------------------------------
    # TRP: Attributes
    #-----------------------------------------
    context "attributes method" do
      should "create writers if class has been declared mutable" do
        @model.class_eval do
          attributes :a
          write_with :test
          attribute :b
        end
        instance = @model.new
        assert instance.respond_to?(:a=)
        assert instance.respond_to?(:b=)
      end
    end


    #-----------------------------------------
    # TRP: Serialization
    #-----------------------------------------
    context "serialization module" do
      setup do
        @hash = { :foo => :bar, :baz => [1,2,3] }
        @model.send :attributes, :hash
        @model.send :serialize, :hash
        @model.send :write_with, :test
      end

      should "deserialize from a YAML serialized object" do
        instance = @model.new(:hash => @hash.to_yaml)
        assert_equal @hash, instance.hash
      end

      should "serialize an object to YAML" do
        instance = @model.new
        instance.hash = @hash
        assert_equal @hash.to_yaml, instance.hash_raw
      end

      should "provide the YAML version through the *_raw command" do
        instance = @model.new(:hash => @hash.to_yaml)
        assert_equal @hash.to_yaml, instance.hash_raw
      end
    end


    #-----------------------------------------
    # TRP: Associations
    #-----------------------------------------
    # TRP: Most association tests use some predefined models to avoid confusion of dynamically creating them.

    context "klass_from_association_options method" do
      setup do
        @comment = Perry::Test::Blog::Comment.new(:parent_type => "Article")
        @subject_on_comment = lambda do |association|
          @comment.send(:klass_from_association_options, association.to_sym, Perry::Test::Blog::Comment.defined_associations[association.to_sym].options.dup)
        end
      end

      should "use extended class when present on a non-polymorphic association" do
        assert_equal Perry::Test::ExtendedBlog::Person, @subject_on_comment.call(:author)
      end

      should "use extended class when present on a polymorphic association" do
        assert_equal Perry::Test::ExtendedBlog::Article, @subject_on_comment.call(:parent)
      end

      should "not use extended class when has a different name" do
        @comment = Perry::Test::Blog::Comment.new(:parent_type => "Site")
        assert_equal Perry::Test::Blog::Site, @subject_on_comment.call(:parent)
      end

    end

    context 'has external associations' do
      setup do
        @adapter.data = { :id => 1 }
        @site = Perry::Test::Blog::Site.first
        @adapter.reset
      end

      should "not query if primary key is nil" do
        @site.id = nil
        assert_nil @site.id
        assert_nil @site.maintainer
        assert_nil @adapter.last_call
      end

      should "use foreign_key when passed" do
        @adapter.data = { :person_id => 2 }
        @comment = Perry::Test::Blog::Comment.first
        @comment.author
        assert_equal [{ :id => 2 }], @adapter.last_call.last[:where]
      end
    end

    context 'has_many external associations' do
      setup do
        @adapter.data = { :id => 1 }
        @site = Perry::Test::Blog::Site.first
        @adapter.reset
      end

      should "return a relation" do
        assert_equal Perry::Relation, @site.articles.class
      end

      should "add proper :where conditions for remote model" do
        assert_equal [{ :site_id => 1 }], @site.articles.where_values
      end

      should "set :parent_type, and :parent_id params if :as config used in association declaration" do
        assert_equal [{ :parent_id => 1 }, { :parent_type => "Site" }], @site.comments.where_values
      end

      should "use only :sql option for query if it is passed" do
        relation = @site.awesome_comments
        relation.all
        assert_nil @adapter.last_call.last[:where]
        assert_match /awesome/, relation.raw_sql_value
      end
    end

    context "has_one external association" do
      setup do
        @adapter.data = { :id => 1, :maintainer_id => 1 }
        @site = Perry::Test::Blog::Site.first
        @adapter.reset
      end

      should "return a single object" do
        @adapter.data = { :id => 1 }
        assert_kind_of Perry::Base, @site.maintainer
      end

      should "add proper :where conditions for remote model" do
        @site.headline
        assert_equal [{ :site_id => 1 }], @adapter.last_call.last[:where]
      end

      should "set :parent_type, and :parent_id params if :as config used in association declaration" do
        @site.master_comment
        assert_equal [{ :parent_id => 1 }, { :parent_type => "Site" }], @adapter.last_call.last[:where]
      end

      should "use only :sql option for query if it is passed" do
        @site.fun_articles
        assert_nil @adapter.last_call.last[:where]
        assert_match /monkeyonabobsled/, @adapter.last_call.last[:sql]
      end


    end

    context "belongs_to external association" do
      setup do
        @adapter.data = { :author_id => 1 }
        @article = Perry::Test::Blog::Article.first
        @adapter.reset
      end

      should "add proper :where conditions for remote model" do
        @article.author
        assert_equal [{ :id => 1 }], @adapter.last_call.last[:where]
      end

      should "return a single object" do
        @adapter.data = { :id => 1 }
        assert_kind_of Perry::Base, @article.author
      end
    end

    context "contains associations" do
      setup do
        @subwidgets = (1..5).collect { Factory(:subwidget).tap { |hsh| hsh.each_key { |k| hsh[k.to_s] = hsh.delete(k) } } }
        @schematic = Factory(:schematic).tap { |hsh| hsh.each_key { |k| hsh[k.to_s] = hsh.delete(k) } }
        @adapter.data = Factory(:widget).merge(:subwidgets => @subwidgets, :schematic => @schematic)
        @widget = Perry::Test::Warehouse::Widget.first
      end

      context "contains_one association" do
        should "instantiate contains one association with the embedded attributes" do
          assert @widget.schematic
          assert_equal @schematic, @widget.schematic.attributes
        end

        should "use the extended version of the associated class if available" do
          assert_kind_of Perry::Test::ExtendedWarehouse::Schematic, @widget.schematic
        end
      end

      context "contains_many association" do
        should "instantiate contains many association with the embedded attributes" do
          assert @widget.subwidgets
          assert_equal @subwidgets, @widget.subwidgets.collect { |sw| sw.attributes }
        end
      end
    end

  end

end
