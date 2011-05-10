require "#{File.dirname(__FILE__)}/../../test_helper"

class Perry::Processors::PreloadAssociationsTest < Test::Unit::TestCase

  context "AssociationPreload processor" do
    setup do
      @model = Class.new(Perry::Test::Base)
      @model.send(:attributes, :id)
      @model.class_eval do
        read_with :test
        configure_read do |config|
          config.add_processor(Perry::Processors::PreloadAssociations, {})
        end
      end
      @adapter = @model.read_adapter
      @relation = @model.scoped

      @site = Perry::Test::Blog::Site
      @article = Perry::Test::ExtendedBlog::Article
      @comment = Perry::Test::ExtendedBlog::Comment
      @person = Perry::Test::ExtendedBlog::Person

      Perry::Test::Blog::Person.modifiers(:reset_cache => true).first
      @adapter.reset

      increment = proc { |i| (i ? i[:id] : 0) + 1 }
      @adapter.data = {
        @site => {
          :id => increment,
          :maintainer_id => 100
        },
        @article => {
          :id => 1,
          :site_id => 1
        },
        @comment => {
          :id => 1,
          :parent_id => 2,
          :parent_type => "Site"
        },
        @person => {
          :id => 100
        },
        @model => {
          :id => 1
        }
      }
      @adapter.count = 5
    end

    teardown do
      @adapter.reset
    end

    should "not effect a normal request" do
      @adapter.count = 1
      result = @adapter.call(:read, :relation => @relation)
      assert_equal [{'id' => 1}], result.collect(&:attributes)
      assert_equal 1, @adapter.calls.size
    end

    should "run n additional queries n = number of associations in :includes" do
      @site.scoped.includes(:articles, 'comments', :maintainer).all
      assert_equal 4, @adapter.calls.size
    end

    should "include the results for preloads" do
      sites = @site.includes(:articles, :comments, :maintainer, :headline).all
      call_count = @adapter.calls.size

      # has_many
      assert_equal Perry::Relation, sites.first.articles.class
      sites.first.articles.records.each do |article|
        assert_equal @article, article.class
      end

      # has_many polymorphic
      assert_equal Perry::Relation, sites.first.comments.class
      sites.first.comments.records.each do |comment|
        assert_equal @comment, comment.class
      end

      # belongs_to
      assert_equal @person, sites.first.maintainer.class

      # has_one
      assert_equal @article, sites.first.headline.class

      # Ensure no more calls were made during our assertions
      assert_equal call_count, @adapter.calls.size
    end

    should "only include records that match for a given model" do
      sites = @site.includes(:articles, :comments, :maintainer, :headline).all
      call_count = @adapter.calls.size

      # Verify
      sites.each do |site|
        site.articles.each do |article|
          assert_equal site.id, article.site_id
        end

        site.comments.each do |comment|
          assert_equal site.id, comment.parent_id
          assert_equal 'Site', comment.parent_type
        end

        assert_equal site.maintainer_id, site.maintainer.id
        assert_equal site.id, site.headline.site_id if site.id == 1
      end

      assert_equal call_count, @adapter.calls.size
    end

    should "include modifiers from original query in subsequent queries" do
      test = { :agentp => "platyous", :agentm => "monkey" }
      sites = @site.modifiers(test).includes(:articles, :comments, :maintainer, :headline).all

      @adapter.calls.each do |call|
        assert_equal test, call[1][:relation].modifiers_value
      end
    end

    should "cache results for collection associations in a relation with correct scope" do
      site = @site.includes(:articles, :comments).first

      assert_equal site.defined_associations[:articles].scope(site).to_hash, site.articles.to_hash
      assert_equal site.defined_associations[:comments].scope(site).to_hash, site.comments.to_hash
    end

    should "raise AssociationNotFound for nonexistant associations in :includes" do
      assert_raises(Perry::AssociationNotFound) do
        @site.includes(:poop_on_a_stick).all
      end
    end

    should "raise AssociationPreloadNotSupported if association requires an instance" do
      assert_raises(Perry::AssociationPreloadNotSupported) do
        @site.includes(:fun_articles).all
      end
    end

  end

end

