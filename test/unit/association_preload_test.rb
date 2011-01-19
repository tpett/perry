require "#{File.dirname(__FILE__)}/../test_helper"

class RPCMapper::AssociationPreloadTest < Test::Unit::TestCase

  context "BertMapper::Base with AssociationPreload class" do
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
    # TRP: Association Preload (eager loading)
    #-----------------------------------------
    context "includes query method" do
      setup do
        @adapter.data = { :id => 1, :site_id => 1, :parent_id => 1, :parent_type => "Site", :maintainer_id => 1 }
        @adapter.count = 5
        @site = RPCMapper::Test::Blog::Site
        @article = RPCMapper::Test::ExtendedBlog::Article
      end

      should "run 1+n queries where n is the # of associations to load" do
        sites = @site.scoped.includes(:articles, :comments, :maintainer).all
        assert_equal 4, @adapter.calls.size
      end

      should "include the eager loaded associations on the model" do
        sites = @site.scoped.all(:includes => [:articles, :comments, :maintainer])

        assert_equal RPCMapper::Relation, sites.first.articles.class
        assert_equal @article, sites.first.articles[0].class

        assert_equal RPCMapper::Relation, sites.first.comments.class
        assert_equal RPCMapper::Test::ExtendedBlog::Comment, sites.first.comments[0].class

        assert_equal RPCMapper::Test::ExtendedBlog::Person, sites.first.maintainer.class
      end

      should "force eager loaded association to reload with fresh scope" do
        sites = @site.scoped.includes(:articles).all
        assert_equal @adapter.count, sites.first.articles.size

        @adapter.count = 6
        calls = @adapter.calls.size

        assert_not_equal @adapter.count, sites.first.articles.size
        assert_equal @adapter.count, sites.first.articles.fresh.size
        assert_equal calls + 1, @adapter.calls.size
      end

      should "raise AssociationNotFound for nonexistant associations" do
        assert_raises RPCMapper::AssociationNotFound do
          @site.scoped.includes(:foobar).all
        end
      end

      should "raise AssociationPreloadNotSupported if association requires an instance (has block options)" do
        assert_raises(RPCMapper::AssociationPreloadNotSupported) do
          @site.scoped.includes(:awesome_comments).all
        end
      end

    end
  end

end
