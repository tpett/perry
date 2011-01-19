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

      should "sanitize malicious values in _type column" do
        comment = RPCMapper::Test::Blog::Comment.new(:parent_type => "Site;::UHOH = true")
        comment.class.defined_associations[:parent].target_klass(comment)
        assert_raises(NameError) { UHOH }
      end

      should "raise PolymorphicAssociationTypeError for missing types" do
        comment = RPCMapper::Test::Blog::Comment.new(:parent_type => "OhSnap")
        assert_raises(RPCMapper::PolymorphicAssociationTypeError) do
          comment.class.defined_associations[:parent].target_klass(comment)
        end
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

    context "scope method" do
      setup do
        @article = RPCMapper::Test::Blog::Article
      end

      should "return nil if no foreign_key present" do
        record = @article.new
        assert_nil @article.defined_associations[:site].scope(record)
      end

      should "return a scope for the target class if association present" do
        record = @article.new(:site_id => 1)
        assert_equal(RPCMapper::Relation, @article.defined_associations[:site].scope(record).class)
      end

      should "the scope should have the options for he association query" do
        record = @article.new(:site_id => 1)
        assert_equal({ :id => 1 }, @article.defined_associations[:site].scope(record).where_values.first)
      end

    end

  end

  context "has associations" do
    setup do
      @blog = RPCMapper::Test::Blog
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

      should "return {:as}_id on polymorphic associations by default" do
        poly_association = @klass.new(@model, 'bar', :as => :parent)
        assert_equal :parent_id, poly_association.foreign_key
      end

      should "return the lowercase source class name followed by _id if association is not polymorphic" do
        articles = @blog::Site.defined_associations[:articles]
        assert_equal :site_id, articles.foreign_key
      end

      should "use :foreign_key option if specified" do
        a = @klass.new(@model, 'bar', :as => :parent, :foreign_key => :purple_monkey)
        assert_equal :purple_monkey, a.foreign_key
      end

    end

    context "scope method" do
      setup do
        @article = RPCMapper::Test::Blog::Article
      end

      should "return nil if no foreign_key present" do
        record = @article.new
        assert_nil @article.defined_associations[:comments].scope(record)
      end

      should "return a scope for the target class if association present" do
        record = @article.new(:id => 1)
        assert_equal(RPCMapper::Relation, @article.defined_associations[:comments].scope(record).class)
      end

      should "the scope should have the options for the association method" do
        record = @article.new(:id => 1)
        assert_equal([{ :parent_id => 1 }, { :parent_type => "Article" }], @article.defined_associations[:comments].scope(record).where_values)
      end

      should "include base association options in the scope" do
        record = @article.new(:id => 1)
        assert_equal "text LIKE '%awesome%'", @article.defined_associations[:awesome_comments].scope(record).where_values.first
      end
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
