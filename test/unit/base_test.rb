require "#{File.dirname(__FILE__)}/../test_helper"

class RPCMapper::BaseTest < Test::Unit::TestCase

  context "BertMapper::Base class" do
    setup do
      @model = Class.new(RPCMapper::Test::Base)
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

    context "persistence methods" do
      setup do
        @model.class_eval do
          attributes :a, :b, :c
          write_with :test

          configure_write do |config|
            config.post_body_wrapper = "test"
          end
        end
      end

      should "require bert_mapper/persistence if needed" do
        assert defined?(RPCMapper::Persistence)
      end

      should "include RPCMapper::Mutable module" do
        assert @model.ancestors.include?(RPCMapper::Persistence)
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
    end

    context "configure_cacheable method" do
      setup do
        @expires = Time.now
        @model.send(:configure_cacheable, :expires => @expires, :record_count_threshold => 5)
      end

      should "include RPCMapper::Cacheable module" do
        assert @model.ancestors.include?(RPCMapper::Cacheable)
      end

      should "set configuration vars" do
        assert_equal @expires, @model.send(:cache_expires)
        assert_equal 5, @model.send(:cache_record_count_threshold)
      end
    end


    # TRP: new_record flag control
    should "set new_record true when a new object is created directly" do
      assert @model.new.new_record?
    end

    context "new_from_data_store method" do
      setup do
        @attributes = Factory(:widget)
        @widget = RPCMapper::Test::Wearhouse::Widget.new_from_data_store(@attributes)
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
        assert_nil RPCMapper::Test::Wearhouse::Widget.new_from_data_store(nil)
      end
    end

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

    COMPARISON_COND = RPCMapper::Scopes::Conditions::COMPARISON_CONDITIONS
    WILDCARD_COND   = RPCMapper::Scopes::Conditions::WILDCARD_CONDITIONS
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
            assert_kind_of RPCMapper::Relation, @model.send("a_#{method}", 'foo')
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
    # TRP: Cacheable
    #-----------------------------------------
    context "with cacheable set" do
      setup do
        @model.send :attributes, :id, :name, :expire_at
        @model.send :configure_cacheable, :record_count_threshold => 3, :expires => :expire_at
        @adapter.data = { :id => 1, :name => "Foo", :expire_at => Time.now + 60 }
      end

      should "only execute one call for two duplicate requests" do
        assert_equal @model.first, @model.first
        assert_equal 1, @adapter.calls.size
      end

      should "only cache if the record count is within threshold" do
        @model.limit(4).all
        @model.limit(4).all
        assert_equal 2, @adapter.calls.size
      end

      should "rerun query if cache is expired" do #should "use :expires option attribute on fresh data to set expire time if :expires option present"
        @adapter.data = @adapter.data.merge(:expire_at => Time.now)
        @model.first
        @model.first
        assert_equal 2, @adapter.calls.size
      end

      should "set fresh to false if data is from cache and to true if data is not from cache" do
        assert @model.first.fresh
        assert !@model.first.fresh
      end

      should "rerun query if fresh scope called" do
        assert_not_equal @model.fresh.first, @model.fresh.first
        assert_equal 2, @adapter.calls.size
      end

      should "rerun query if :fresh finder option passed" do
        assert_not_equal @model.first(:fresh => true), @model.first(:fresh => true)
        assert_equal 2, @adapter.calls.size
      end

      context "reset_cache_store method" do

        should "clear out cache store" do
          @extend_model = Class.new(@model)
          @extend_model.first
          @model.reset_cache_store
          @extend_model.first
          assert_equal 2, @adapter.calls.size
        end

      end

    end


    #-----------------------------------------
    # TRP: Persistence
    #-----------------------------------------
    context "persistence methods" do
      setup do
        @model.class_eval do
          attributes :a, :b
          write_with :test
        end
        @object = @model.new
      end

      should "call write method on the write_adapter when save called" do
        assert @object.save
        assert_equal @object, @model.write_adapter.last_call.last
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
        assert_equal obj, @model.write_adapter.last_call.last
        assert_equal 'a', obj.a
        assert_equal 'c', obj.b
      end

      should "raise exception if save! or update_attributes! called and failed" do
        @object.write_adapter.writes_return false
        assert_raises(RPCMapper::RecordNotSaved) { @object.save! }
        assert_raises(RPCMapper::RecordNotSaved) { @object.update_attributes!({}) }
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
        @comment = RPCMapper::Test::Blog::Comment.new(:parent_type => "Article")
        @subject_on_comment = lambda do |association|
          @comment.send(:klass_from_association_options, association.to_sym, RPCMapper::Test::Blog::Comment.defined_associations[association.to_sym].options.dup)
        end
      end

      should "use extended class when present on a non-polymorphic association" do
        assert_equal RPCMapper::Test::ExtendedBlog::Person, @subject_on_comment.call(:author)
      end

      should "use extended class when present on a polymorphic association" do
        assert_equal RPCMapper::Test::ExtendedBlog::Article, @subject_on_comment.call(:parent)
      end

      should "not use extended class when has a different name" do
        @comment = RPCMapper::Test::Blog::Comment.new(:parent_type => "Site")
        assert_equal RPCMapper::Test::Blog::Site, @subject_on_comment.call(:parent)
      end

    end

    context 'has external associations' do
      setup do
        @adapter.data = { :id => 1 }
        @site = RPCMapper::Test::Blog::Site.first
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
        @comment = RPCMapper::Test::Blog::Comment.first
        @comment.author
        assert_equal [{ :id => 2 }], @adapter.last_call.last[:where]
      end
    end

    context 'has_many external associations' do
      setup do
        @adapter.data = { :id => 1 }
        @site = RPCMapper::Test::Blog::Site.first
        @adapter.reset
      end

      should "return a relation" do
        assert_equal RPCMapper::Relation, @site.articles.class
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
        @site = RPCMapper::Test::Blog::Site.first
        @adapter.reset
      end

      should "return a single object" do
        @adapter.data = { :id => 1 }
        assert_kind_of RPCMapper::Base, @site.maintainer
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
        @article = RPCMapper::Test::Blog::Article.first
        @adapter.reset
      end

      should "add proper :where conditions for remote model" do
        @article.author
        assert_equal [{ :id => 1 }], @adapter.last_call.last[:where]
      end

      should "return a single object" do
        @adapter.data = { :id => 1 }
        assert_kind_of RPCMapper::Base, @article.author
      end
    end

    context "contains associations" do
      setup do
        @subwidgets = (1..5).collect { Factory(:subwidget).tap { |hsh| hsh.each_key { |k| hsh[k.to_s] = hsh.delete(k) } } }
        @schematic = Factory(:schematic).tap { |hsh| hsh.each_key { |k| hsh[k.to_s] = hsh.delete(k) } }
        @adapter.data = Factory(:widget).merge(:subwidgets => @subwidgets, :schematic => @schematic)
        @widget = RPCMapper::Test::Wearhouse::Widget.first
      end

      context "contains_one association" do
        should "instantiate contains one association with the embedded attributes" do
          assert @widget.schematic
          assert_equal @schematic, @widget.schematic.attributes
        end

        should "use the extended version of the associated class if available" do
          assert_kind_of RPCMapper::Test::ExtendedWearhouse::Schematic, @widget.schematic
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
