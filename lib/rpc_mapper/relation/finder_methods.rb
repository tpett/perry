module RPCMapper::FinderMethods

  def find(ids_or_mode, options={})
    case ids_or_mode
    when Fixnum, String
      self.where(:id => ids_or_mode.to_i).first(options) || raise(RPCMapper::RecordNotFound, "Could not find #{@klass} with :id = #{ids_or_mode}")
    when Array
      self.where(:id => ids_or_mode).all(options).tap do |result|
        raise RPCMapper::RecordNotFound, "Couldn't find all #{@klass} with ids (#{ids_or_mode.join(',')}) (expected #{ids_or_mode.size} records but got #{result.size})." unless result.size == ids_or_mode.size
      end
    when :all
      self.all(options)
    when :first
      self.first(options)
    else
      raise ArgumentError, "Unknown arguments for method find"
    end
  end

  def all(options={})
    self.apply_finder_options(options).to_a
  end

  def first(options={})
    self.apply_finder_options(options).limit(1).to_a.first
  end

  def search(options={})
    relation = self
    options.each do |search, *args|
      relation = relation.send(search, *args) if @klass.send(:condition_details, search)
    end
    relation
  end

  def apply_finder_options(options)
    relation = clone
    return relation unless options

    [:joins, :limit, :offset, :order, :select, :group, :having, :from, :fresh, :includes].each do |finder|
      relation = relation.send(finder, options[finder]) if options[finder]
    end

    relation = relation.where(options[:conditions]) if options.has_key?(:conditions)
    relation = relation.where(options[:where]) if options.has_key?(:where)

    relation = relation.includes(options[:include]) if options.has_key?(:include)

    relation = relation.search(options[:search]) if options.has_key?(:search)

    relation = relation.sql(options[:sql]) if options.has_key?(:sql)

    relation
  end

end
