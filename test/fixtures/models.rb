module Perry::Test
  class Base < Perry::Base
    read_with :test
  end

  module Wearhouse
    class Widget < Perry::Test::Base
      attributes :string, :integer, :float, :text
      contains_many :subwidgets, :class_name => "Perry::Test::Wearhouse::Subwidget"
      contains_one :schematic, :class_name => "Perry::Test::Wearhouse::Schematic"
    end

    class Subwidget < Perry::Test::Base
      attributes :string
    end
    class Schematic < Perry::Test::Base
      attributes :string
    end
  end

  module ExtendedWearhouse
    class Schematic < Perry::Test::Wearhouse::Schematic; end
  end

  # TRP: Used for testing external associations
  module Blog
    class Site < Perry::Test::Base
      attributes :id, :name, :maintainer_id
      write_with :test
      belongs_to :maintainer, :class_name => "Perry::Test::Blog::Person"
      has_one :headline, :class_name => "Perry::Test::Blog::Article"
      has_one :master_comment, :as => :parent, :class_name => "Perry::Test::Blog::Comment"
      has_one :fun_articles, {
        :class_name => "Perry::Test::Blog::Article",
        :conditions => "1",
        :sql => lambda { |s|
          %Q{
            SELECT articles.*
            FROM articles
            WHERE articles.text LIKE %monkeyonabobsled% AND articles.site_id = #{s.id}
          }
        }
      }
      has_many :articles, :class_name => "Perry::Test::Blog::Article"
      has_many :article_comments, :through => :articles, :source => :comments
      has_many :maintainer_articles, :through => :maintainer, :source => :articles
      has_many :comments, :as => :parent, :class_name => "Perry::Test::Blog::Comment"
      has_many :awesome_comments, {
        :class_name => "Perry::Test::Blog::Comment",
        :conditions => "1",
        :sql => lambda { |s|
          %Q{
            SELECT comments.*
            FROM comments
            WHERE comments.text LIKE '%awesome%' AND parent_type = "Site" AND parent_id = #{s.id}
          }
        }
      }
    end

    class Article < Perry::Test::Base
      attributes :id, :site_id, :author_id, :title, :text
      belongs_to :site, :class_name => "Perry::Test::Blog::Site"
      belongs_to :author, :class_name => "Perry::Test::Blog::Person"
      has_many :comments, :as => :parent, :class_name => "Perry::Test::Blog::Comment"
      has_many :comment_authors, :through => :comments, :source => :author
      has_many :awesome_comments, :as => :parent, :class_name => "Perry::Test::Blog::Comment",
        :conditions => "text LIKE '%awesome%'"
    end

    class Comment < Perry::Test::Base
      attributes :id, :person_id, :parent_id, :parent_type, :text
      belongs_to :parent, :polymorphic => true, :polymorphic_namespace => "Perry::Test::Blog"
      belongs_to :author, :class_name => "Perry::Test::Blog::Person", :foreign_key => :person_id
    end

    class Person < Perry::Test::Base
      attributes :id, :name, :manager_id
      configure_cacheable
      belongs_to :manager, :class_name => "Perry::Test::Blog::Person", :foreign_key => :manager_id
      has_many :authored_comments, :class_name => "Perry::Test::Blog::Comment", :foreign_key => :person_id
      has_many :articles, :class_name => "Perry::Test::Blog::Article", :foreign_key => :author_id
      has_many :comments, :as => :parent, :class_name => "Perry::Test::Blog::Comment"
      has_many :commented_articles, :through => :comments, :source => :parent,
        :source_type => "Article"
      has_many :employees, :class_name => "Perry::Test::Blog::Person", :foreign_key => :manager_id
      has_many :sites, :class_name => "Perry::Test::Blog::Site", :foreign_key => :maintainer_id
      has_many :site_comments, :through => :sites, :source => :comments
    end

  end

  module ExtendedBlog
    class Site2 < Perry::Test::Blog::Site; end
    class Article < Perry::Test::Blog::Article; end
    class Comment < Perry::Test::Blog::Comment; end
    class Person < Perry::Test::Blog::Person; end
  end

end
