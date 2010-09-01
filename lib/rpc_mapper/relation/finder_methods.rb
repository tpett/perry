module RPCMapper::FinderMethods

  def find(ids_or_mode, options={})
    case ids_or_mode
    when Fixnum, String
      self.where(:id => ids_or_mode.to_i).first(options)
    when Array
      self.where(:id => ids_or_mode).all(options)
    when :all
      self.all(options)
    when :first
      self.first(options)
    else
      raise ArgumentError, "Unknown arguments for method find"
    end
  end

  def all(options={})
    self.apply_finder_options(options).fetch_records
  end

  def first(options={})
    self.apply_finder_options(options).limit(1).fetch_records.first
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

    [:joins, :limit, :offset, :order, :select, :group, :having, :from].each do |finder|
      relation = relation.send(finder, options[finder]) if options[finder]
    end

    relation = relation.where(options[:conditions]) if options.has_key?(:conditions)
    relation = relation.where(options[:where]) if options.has_key?(:where)

    relation = relation.search(options[:search]) if options.has_key?(:search)

    relation = relation.sql(options[:sql]) if options.has_key?(:sql)

    relation
  end

end
