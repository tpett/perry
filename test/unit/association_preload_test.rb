require "#{File.dirname(__FILE__)}/../test_helper"

class Perry::AssociationPreloadTest < Test::Unit::TestCase

  context "Perry::Base with AssociationPreload class" do
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
    # TRP: Association Preload (eager loading)
    #-----------------------------------------
    context "includes query method" do
      setup do
        @adapter.data = {
          :id => 1,
          :site_id => 1,
          :parent_id => 1,
          :parent_type => "Site",
          :maintainer_id => 1,
          :person_id => 1
        }
        @adapter.count = 5
        @site = Perry::Test::Blog::Site
        @article = Perry::Test::ExtendedBlog::Article

        Perry::Test::Blog::Person.reset_cache_store
      end

      should "run 1+n queries where n is the # of associations to load" do
        sites = @site.scoped.includes(:articles, :comments, :maintainer).all
        assert_equal 4, @adapter.calls.size
      end

      should "include the eager loaded associations on the model" do
        sites = @site.scoped.all(:includes => [:articles, :comments, :maintainer])

        assert_equal Perry::Relation, sites.first.articles.class
        assert_equal @article, sites.first.articles[0].class

        assert_equal Perry::Relation, sites.first.comments.class
        assert_equal Perry::Test::ExtendedBlog::Comment, sites.first.comments[0].class

        assert_equal Perry::Test::ExtendedBlog::Person, sites.first.maintainer.class
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

      should "calling fresh on a relation should cause any eager loaded associations to freshen as well" do
        @person = Perry::Test::ExtendedBlog::Person
        people = @person.scoped.includes(:employees)

        # No calls yet
        assert_equal 0, @adapter.calls.size

        # Two calls -- one for people, and one for employees
        people.to_a
        assert_equal 2, @adapter.calls.size

        # No new calls -- everything should be cached
        people.to_a
        assert_equal 2, @adapter.calls.size

        # Two more calls -- again one for people, and one for employees
        people.fresh.to_a

        assert_equal 4, @adapter.calls.size
      end

      should "raise AssociationNotFound for nonexistant associations" do
        assert_raises Perry::AssociationNotFound do
          @site.scoped.includes(:foobar).all
        end
      end

      should "raise AssociationPreloadNotSupported if association requires an instance (has block options)" do
        assert_raises(Perry::AssociationPreloadNotSupported) do
          @site.scoped.includes(:awesome_comments).all
        end
      end

    end
  end

end
