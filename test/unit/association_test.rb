require "#{File.dirname(__FILE__)}/../test_helper"

class RPCMapper::AssociationTest < Test::Unit::TestCase

  context "generic association" do
    setup do
      @klass = RPCMapper::Association::Base
      @model = Class.new(RPCMapper::Base)
      @association = @klass.new(@model, "foo")
    end

    context "eager_loadable? method" do
      should "return true if options do not rely on instance data" do
        assert @association.eager_loadable?
      end

      should "return false if :sql option used" do
        assert !@klass.new(@model, 'bar', :sql => "some sql statement").eager_loadable?
      end

      should "return false if a block is used for the param of any finder option" do
        RPCMapper::Relation::FINDER_OPTIONS.each do |option|
          assert !@klass.new(@model, 'bar', option => lambda {}).eager_loadable?
        end
      end
    end

    # TRP: These tests use the models fixture
    context "target_klass method" do

      #should "not return extensions of the class if the extended class name is not the same" # Covered by next test
      should "return the class specified by :class_name option" do
        assert_equal RPCMapper::Test::Blog::Site, RPCMapper::Test::Blog::Article.defined_associations[:site].target_klass
      end

      should "return the latest extension of the specified class if the extended class is of the same name" do
        assert_equal RPCMapper::Test::ExtendedBlog::Article, RPCMapper::Test::Blog::Site.defined_associations[:articles].target_klass
      end

      #should "use the :polymorphic_namespace if given as an option" # Covered by next test
      should "use the optional object parameter's polymorphic _type attribute to determine the class if :polymorphic is true" do
        comment = RPCMapper::Test::Blog::Comment.new(:parent_type => "Site")
        assert_equal RPCMapper::Test::Blog::Site, comment.class.defined_associations[:parent].target_klass(comment)
      end

    end

    context "scope method" do
      setup do
        @article = RPCMapper::Test::Blog::Article
      end
      should "return a scope for the target class" do
        record = @article.new
        assert_equal RPCMapper::Relation, @article.defined_associations[:site].scope(record).class
      end

      should "the scope should have the options from the finder_options method" do
        record = @article.new(:site_id => 1)
        assert_equal({ :id => 1 }, @article.defined_associations[:site].scope(record).where_values.first)
      end
    end

  end

  context ":belongs_to association" do
    setup do
      @klass = RPCMapper::Association::BelongsTo
      @model = Class.new(RPCMapper::Base)
      @association = @klass.new(@model, "foo")
    end

    should "set type to :belongs_to" do
      assert_equal :belongs_to, @association.type
    end

    should "use :id as default primary key" do
      assert_equal :id, @association.primary_key
    end

    should "return false for collection?" do
      assert !@association.collection?
    end

    should "by default return {association_name}_id for foreign key" do
      assert_equal :foo_id, @association.foreign_key
    end

    should "return true for polymorphic? if polymorphic options specified and false otherwise" do
      assert !@association.polymorphic?
      assert @klass.new(@model, 'bar', :polymorphic => true).polymorphic?
    end

    context "finder_options method" do
      # :conditions option will be stomped by the belongs_to condition building
      (RPCMapper::Relation::FINDER_OPTIONS - [:conditions, :where]).each do |option|
        should "contain finder option #{option} if provided on the association" do
          association = @klass.new(@model, "bar_#{option}", option => 'foo')
          assert_equal 'foo', association.finder_options(@model.new)[option]
        end
      end

      should "set a condition that the primary key should equal value of the foreign_key field" do
        model = RPCMapper::Test::Blog::Article
        a = model.defined_associations[:author]
        assert_equal({ :id => 1 }, a.finder_options(model.new_from_data_store(:author_id => 1))[:conditions])
      end

    end

  end

  context "has associations" do
    setup do
      @klass = RPCMapper::Association::Has
      @model = Class.new(RPCMapper::Base)
      @association = @klass.new(@model, "foo")
    end

    should "use :id as default primary key" do
      assert_equal :id, @association.primary_key
    end

    should "return set polymorphic? true if :as option passed and false otherwise" do
      assert !@association.polymorphic?
      assert @klass.new(@model, 'bar', :as => :parent).polymorphic?
    end

    context "foreign_key method" do
      should "return {:as}_id on polymorphic associations by default"
      should "return the lowercase source class name followed by _id if association is not polymorphic"
      should "use :foreign_key option if specified"
    end

    context "finder_options method" do
      should "contain any default finder options on the association"
      should "set a condition for :foreign_key to equal the source object's primary key"

      # should "push conditions onto an array if conditions applied on association declaration" do
      #   model = RPCMapper::Test::Blog::Article
      #   a = model.defined_associations[:awesome_comments]
      #   obj = model.new_from_data_store(:id => 1)
      #   assert_equal ["text LIKE '%awesome%'", {:parent_id => 1, :parent_type => "Article"}], a.finder_options(obj)[:conditions]
      # end

      should "set a option for {:as}_type to equal the base class name of the source if polymorphic"
    end

    context "specifically the :has_many association" do
      setup do
        @klass = RPCMapper::Association::HasMany
        @association = @klass.new(@model, "foo")
      end

      should "set type to :has_many" do
        assert_equal :has_many, @association.type
      end

      should "set collection? to true" do
        assert @association.collection?
      end
    end

    context "specifically the :has_one association" do
      setup do
        @klass = RPCMapper::Association::HasOne
        @association = @klass.new(@model, "foo")
      end

      should "set type to :has_one" do
        assert_equal :has_one, @association.type
      end

      should "set collection? to false" do
        assert !@association.collection?
      end
    end

  end


end
