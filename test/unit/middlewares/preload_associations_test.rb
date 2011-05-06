require "#{File.dirname(__FILE__)}/../../test_helper"

class Perry::Middlewares::PreloadAssociationsTest < Test::Unit::TestCase

  context "AssociationPreload middleware" do
    setup do
      @model = Class.new(Perry::Test::Base)
      @model.send(:attributes, :id)
      @adapter = Perry::Adapters::AbstractAdapter.create(:test, proc do |config|
        config.type = :read
        config.add_middleware(Perry::Middlewares::PreloadAssociations, {})
      end)
      @relation = @model.scoped
      @site = Perry::Test::Blog::Site
      @article = Perry::Test::ExtendedBlog::Article

      Perry::Test::Blog::Person.reset_cache_store
    end

    teardown do
      @adapter.reset
    end

    should "not effect a normal request" do
      @adapter.data = { :id => 1 }
      result = @adapter.call(:read, :relation => @relation)
      assert_equal [{:id => 1}], result
      assert_equal 1, @adapter.calls.size
    end

    should "run n additional queries n = number of associations in :includes" do
      @site.scoped.includes(:articles, 'comments', :maintainer).all
      assert_equal 4, @adapter.calls.size
    end

    should "include the results for preloads in :preloaded_associations response hash"
    should "include modifiers from original query in subsequent queries"
    should "raise AssociationNotFound for nonexistant associations in :includes"
    should "raise AssociationPreloadNotSupported if association requires an instance"

    # TODO: load models from fetched data for associations

  end

end

