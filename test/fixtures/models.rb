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
      attributes :id, :name
      write_with :test
      has_one :maintainer, :class_name => "RPCMapper::Test::Blog::Person"
      has_one :master_comment, :as => :parent, :class_name => "RPCMapper::Test::Blog::Comment"
      has_one :fun_articles, lambda { |site|
        {
          :class_name => "RPCMapper::Test::Blog::Article",
          :conditions => "1",
          :sql => %{
            SELECT articles.*
            FROM articles
            WHERE articles.text LIKE %monkeyonabobsled% AND articles.site_id = #{site.id}
          }
        }
      }
      has_many :articles, :class_name => "RPCMapper::Test::Blog::Article"
      has_many :comments, :as => :parent, :class_name => "RPCMapper::Test::Blog::Comment"
      has_many :awesome_comments, lambda { |site|
        {
               :class_name => "RPCMapper::Test::Blog::Comment",
               :conditions => "1",
               :sql => %{
                  SELECT comments.*
                  FROM comments
                  WHERE comments.text LIKE '%awesome%' AND parent_type = "Site" AND parent_id = #{site.id}
               }
        }
      }
    end

    class Article < RPCMapper::Test::Base
      attributes :id, :site_id, :author_id, :title, :text
      belongs_to :site, :class_name => "RPCMapper::Test::Blog::Site"
      belongs_to :author, :class_name => "RPCMapper::Test::Blog::Person"
      has_many :comments, :as => :parent, :class_name => "RPCMapper::Test::Blog::Comment"
    end

    class Comment < RPCMapper::Test::Base
      attributes :id, :person_id, :parent_id, :parent_type, :text
      belongs_to :parent, :polymorphic => true, :polymorphic_namespace => "RPCMapper::Test::Blog"
      belongs_to :author, :class_name => "RPCMapper::Test::Blog::Person", :foreign_key => :person_id
    end

    class Person < RPCMapper::Test::Base
      attributes :id, :name, :site_id
      has_many :authored_comments, :class_name => "RPCMapper::Test::Blog::Comment", :foreign_key => :person_id
      has_many :articles, :class_name => "RPCMapper::Test::Blog::Article"
      has_many :comments, :as => :parent, :class_name => "RPCMapper::Test::Blog::Comment"
    end

  end

  module ExtendedBlog
    class Site2 < RPCMapper::Test::Blog::Site; end
    class Article < RPCMapper::Test::Blog::Article; end
    class Comment < RPCMapper::Test::Blog::Comment; end
    class Person < RPCMapper::Test::Blog::Person; end
  end

end
