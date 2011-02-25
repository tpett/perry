module RPCMapper::Test
  class Base < RPCMapper::Base
    read_with :test
  end

  module Wearhouse
    class Widget < RPCMapper::Test::Base
      attributes :string, :integer, :float, :text
      contains_many :subwidgets, :class_name => "RPCMapper::Test::Wearhouse::Subwidget"
      contains_one :schematic, :class_name => "RPCMapper::Test::Wearhouse::Schematic"
    end

    class Subwidget < RPCMapper::Test::Base
      attributes :string
    end
    class Schematic < RPCMapper::Test::Base
      attributes :string
    end
  end

  module ExtendedWearhouse
    class Schematic < RPCMapper::Test::Wearhouse::Schematic; end
  end

  # TRP: Used for testing external associations
  module Blog
    class Site < RPCMapper::Test::Base
      attributes :id, :name, :maintainer_id
      write_with :test
      belongs_to :maintainer, :class_name => "RPCMapper::Test::Blog::Person"
      has_one :headline, :class_name => "RPCMapper::Test::Blog::Article"
      has_one :master_comment, :as => :parent, :class_name => "RPCMapper::Test::Blog::Comment"
      has_one :fun_articles, {
        :class_name => "RPCMapper::Test::Blog::Article",
        :conditions => "1",
        :sql => lambda { |s|
          %Q{
            SELECT articles.*
            FROM articles
            WHERE articles.text LIKE %monkeyonabobsled% AND articles.site_id = #{s.id}
          }
        }
      }
      has_many :articles, :class_name => "RPCMapper::Test::Blog::Article"
      has_many :article_comments, :through => :articles, :source => :comments
      has_many :maintainer_articles, :through => :maintainer, :source => :articles
      has_many :comments, :as => :parent, :class_name => "RPCMapper::Test::Blog::Comment"
      has_many :awesome_comments, {
        :class_name => "RPCMapper::Test::Blog::Comment",
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

    class Article < RPCMapper::Test::Base
      attributes :id, :site_id, :author_id, :title, :text
      belongs_to :site, :class_name => "RPCMapper::Test::Blog::Site"
      belongs_to :author, :class_name => "RPCMapper::Test::Blog::Person"
      has_many :comments, :as => :parent, :class_name => "RPCMapper::Test::Blog::Comment"
      has_many :comment_authors, :through => :comments, :source => :author
      has_many :awesome_comments, :as => :parent, :class_name => "RPCMapper::Test::Blog::Comment",
        :conditions => "text LIKE '%awesome%'"
    end

    class Comment < RPCMapper::Test::Base
      attributes :id, :person_id, :parent_id, :parent_type, :text
      belongs_to :parent, :polymorphic => true, :polymorphic_namespace => "RPCMapper::Test::Blog"
      belongs_to :author, :class_name => "RPCMapper::Test::Blog::Person", :foreign_key => :person_id
    end

    class Person < RPCMapper::Test::Base
      attributes :id, :name, :manager_id
      configure_cacheable
      belongs_to :manager, :class_name => "RPCMapper::Test::Blog::Person", :foreign_key => :manager_id
      has_many :authored_comments, :class_name => "RPCMapper::Test::Blog::Comment", :foreign_key => :person_id
      has_many :articles, :class_name => "RPCMapper::Test::Blog::Article", :foreign_key => :author_id
      has_many :comments, :as => :parent, :class_name => "RPCMapper::Test::Blog::Comment"
      has_many :commented_articles, :through => :comments, :source => :parent,
        :source_type => "Article"
      has_many :employees, :class_name => "RPCMapper::Test::Blog::Person", :foreign_key => :manager_id
    end

  end

  module ExtendedBlog
    class Site2 < RPCMapper::Test::Blog::Site; end
    class Article < RPCMapper::Test::Blog::Article; end
    class Comment < RPCMapper::Test::Blog::Comment; end
    class Person < RPCMapper::Test::Blog::Person; end
  end

end
