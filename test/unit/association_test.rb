require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::AssociationTest < Test::Unit::TestCase

  context "generic association" do
    setup do
      @klass = Perry::Association::Base
      @model = Class.new(Perry::Base)
      @association = @klass.new(@model, "foo")
    end

    context "eager_loadable? method" do
      should "return true if options do not rely on instance data" do
        assert @association.eager_loadable?
      end

      should "return false if a block is used for the param of any finder option" do
        Perry::Relation::FINDER_OPTIONS.each do |option|
          assert !@klass.new(@model, 'bar', option => lambda {}).eager_loadable?
        end
      end
    end

    # TRP: These tests use the models fixture
    context "target_klass method" do

      #should "not return extensions of the class if the extended class name is not the same" # Covered by next test
      should "return the class specified by :class_name option" do
        assert_equal Perry::Test::Blog::Site, Perry::Test::Blog::Article.defined_associations[:site].target_klass
      end

      should "return the latest extension of the specified class if the extended class is of the same name" do
        assert_equal Perry::Test::ExtendedBlog::Article, Perry::Test::Blog::Site.defined_associations[:articles].target_klass
      end

      #should "use the :polymorphic_namespace if given as an option" # Covered by next test
      should "use the optional object parameter's polymorphic _type attribute to determine the class if :polymorphic is true" do
        comment = Perry::Test::Blog::Comment.new(:parent_type => "Site")
        assert_equal Perry::Test::Blog::Site, comment.class.defined_associations[:parent].target_klass(comment)
      end

      should "sanitize malicious values in _type column" do
        comment = Perry::Test::Blog::Comment.new(:parent_type => "Site;::UHOH = true")
        comment.class.defined_associations[:parent].target_klass(comment)
        assert_raises(NameError) { UHOH }
      end

      should "raise PolymorphicAssociationTypeError for missing types" do
        comment = Perry::Test::Blog::Comment.new(:parent_type => "OhSnap")
        assert_raises(Perry::PolymorphicAssociationTypeError) do
          comment.class.defined_associations[:parent].target_klass(comment)
        end
      end

    end

  end

  context ":belongs_to association" do
    setup do
      @klass = Perry::Association::BelongsTo
      @model = Class.new(Perry::Base)
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
        @article = Perry::Test::Blog::Article
      end

      should "return nil if no foreign_key present" do
        record = @article.new
        assert_nil @article.defined_associations[:site].scope(record)
      end

      should "return a scope for the target class if association present" do
        record = @article.new(:site_id => 1)
        assert_equal(Perry::Relation, @article.defined_associations[:site].scope(record).class)
      end

      should "the scope should have the options for he association query" do
        record = @article.new(:site_id => 1)
        assert_equal({ :id => 1 }, @article.defined_associations[:site].scope(record).where_values.first)
      end

    end

  end

  context "has associations" do
    setup do
      @blog = Perry::Test::Blog
      @klass = Perry::Association::Has
      @model = Class.new(Perry::Base)
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
        @article = Perry::Test::Blog::Article
      end

      should "return nil if no foreign_key present" do
        record = @article.new
        assert_nil @article.defined_associations[:comments].scope(record)
      end

      should "return a scope for the target class if association present" do
        record = @article.new(:id => 1)
        assert_equal(Perry::Relation,
          @article.defined_associations[:comments].scope(record).class)
      end

      should "the scope should have the options for the association method" do
        record = @article.new(:id => 1)
        assert_equal([{ :parent_id => 1 }, { :parent_type => "Article" }],
          @article.defined_associations[:comments].scope(record).where_values)
      end

      should "include base association options in the scope" do
        record = @article.new(:id => 1)
        assert_equal "text LIKE '%awesome%'",
          @article.defined_associations[:awesome_comments].scope(record).where_values.first
      end

    end

    context "specifically the :has_many association" do
      setup do
        @klass = Perry::Association::HasMany
        @association = @klass.new(@model, "foo")
      end

      should "set type to :has_many" do
        assert_equal :has_many, @association.type
      end

      should "set collection? to true" do
        assert @association.collection?
      end
    end

    context "specifically the :has_many_through association" do
      setup do
        @klass = Perry::Association::HasManyThrough
        @site = Perry::Test::Blog::Site
        @association = @site.defined_associations[:article_comments]
        @adapter = @site.send(:read_adapter)
      end

      teardown do
        @adapter.reset
      end

      should "set type to :has_many_through" do
        assert_equal :has_many_through, @association.type
      end

      should "set collection? to true" do
        assert @association.collection?
      end

      should "not allow polymorphic associations" do
        association = @klass.new(@site, :comments,
                                 :through => :articles, :as => :poop)
        assert !association.polymorphic?
      end

      should "raise an AssociationNotFound exception if :through is not a association on class" do
        assert_raises(Perry::AssociationNotFound) do
          @klass.new(@site, :foo, :through => :bar).proxy_association
        end
      end

      should "raise an AssociationNotFound exception if target association " +
        "is not defined on the proxy association's class" do
        assert_raises(Perry::AssociationNotFound) do
          @klass.new(@site, :foo, :through => :articles).target_association
        end
      end

      should "use association name as target association name" do
        assert_equal(
          :comments,
          @klass.new(
            @site,
            :comments,
            :through => :articles
          ).target_association.id
        )
      end


      should "use :source option as target association name if provided" do
        assert_equal(
          :comments,
          @klass.new(
            @site,
            :foo_comments,
            :through => :articles,
            :source => :comments
          ).target_association.id
        )
      end

      should "return a Relation mapped to the :source association's klass" do
        @adapter.data = { :id => 1 }
        site = @site.first
        comments = site.article_comments

        assert_equal Perry::Relation, comments.class
        assert_equal Perry::Test::ExtendedBlog::Comment, comments.klass
      end

      should "execute 2 adapter queries when fetching association" do
        @adapter.data = { :id => 1 }
        site = @site.first
        before_count = @adapter.calls.size
        site.article_comments.all

        assert_equal 2, @adapter.calls.size - before_count
      end

      ##
      # So here is an example to help define this requirement:
      #
      #   class Article < Base
      #     has_many :comments
      #   end
      #
      #   class Site < Base
      #     has_many :articles
      #     has_many :comments, :through => :articles
      #   end
      #
      # If we have articles on a site with IDs 1,2,3.  Calling site.comments
      # would be equivalent to:
      #
      #   Comment.where(:article_id => [1,2,3])
      #
      context "target is 'has' association" do

        ##
        # This is saying the scope created for has targets should set a condition on the
        # ``foreign_key`` attribute of the target to the value(s) from the ``primary_key``
        # field(s) of the proxy association record(s).
        #
        # More concisely it should generate:
        #
        #   where([target_fk_attribute] => [proxy_primary_key_value(s)])
        #
        should "Use proxy's primary key values and target's foreign key attribute" do
          @adapter.data = { :id => 1 }
          site = @site.first

          # TRP: This will start :id at 1 and increment it by 1 on each request
          @adapter.data = { :id => lambda { |prev| prev ? prev[:id] + 1 : 1 } }
          @adapter.count = 3
          relation = site.article_comments
          assert_equal 1, @adapter.calls.size

          hash = relation.to_hash
          assert_equal(Perry::Test::ExtendedBlog::Comment, relation.klass)
          assert_equal({ :parent_id => [1,2,3] }, hash[:where].first)
          assert_equal({ :parent_type => "Article" }, hash[:where].last)
        end
      end

      context "target is 'belongs' association" do
        ##
        # This is saying the scope created for belongs_to targets should set a condition on the
        # ``primary_key`` attribute of the target to the value(s) from the ``foreign_key``
        # field(s) of the proxy association record(s).
        #
        # More concisely it should generate:
        #
        #   where([target_pk_attribute] => [proxy_foreign_key_value(s)])
        #
        should "Use proxy's foreign key values and target's primary key attribute" do
          @adapter.data = { :id => 1 }
          article = Perry::Test::ExtendedBlog::Article.first

          @adapter.data = {
            :id => lambda { |prev| prev ? prev[:id] + 1 : 1 },
            :person_id => lambda { |prev| prev ? prev[:person_id] + 1 : 11 },
          }
          @adapter.count = 3
          relation = article.comment_authors
          assert_equal 1, @adapter.calls.size

          hash = relation.to_hash
          assert_equal(Perry::Test::ExtendedBlog::Person, relation.klass)
          assert_equal({ :id => [11, 12, 13] }, hash[:where].first)
        end

        should "use source_type to determine target's klass when its association is polymorphic" do
          @adapter.data = { :id => 1 }
          person = Perry::Test::ExtendedBlog::Person.first

          @adapter.data = {
            :id => lambda { |prev| prev ? prev[:id] + 1 : 1 },
            :parent_id => lambda { |prev| prev ? prev[:parent_id] + 1 : 11 },
            :parent_type => "FooBar", # This should be ignored
          }
          @adapter.count = 3
          relation = person.commented_articles
          assert_equal 1, @adapter.calls.size

          # It should figure this out from the :source_type option
          hash = relation.to_hash
          assert_equal(Perry::Test::ExtendedBlog::Article, relation.klass)
          assert_equal({ :id => [11, 12, 13] }, hash[:where].first)
        end
      end

      context "when fresh scope applied" do
        should "refresh proxy call and target call" do
          @adapter.data = { :id => 1 }
          site = @site.first

          before_count = @adapter.calls.size

          relation = site.article_comments

          relation.all
          assert_equal 2, @adapter.calls.size - before_count

          relation.fresh.all
          assert_equal 4, @adapter.calls.size - before_count
        end
      end

    end


    context "specifically the :has_one association" do
      setup do
        @klass = Perry::Association::HasOne
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
