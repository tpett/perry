module Perry::QueryMethods
  # TRP: Define each of the variables the query options will be stored in.
  attr_accessor :select_values, :group_values, :order_values, :joins_values, :includes_value, :where_values, :having_values,
                :limit_value, :offset_value, :from_value, :raw_sql_value

  def select(*args)
    if block_given?
      to_a.select {|*block_args| yield(*block_args) }
    else
      clone.tap { |r| r.select_values += args if args_valid? args }
    end
  end

  def group(*args)
    clone.tap { |r| r.group_values += args if args_valid? args }
  end

  def order(*args)
    clone.tap { |r| r.order_values += args if args_valid? args }
  end

  def joins(*args)
    clone.tap { |r| r.joins_values += args if args_valid?(args) }
  end

  def includes(*args)
    args.reject! { |a| a.nil? }
    clone.tap { |r| r.includes_value = (r.includes_value || {}).deep_merge(sanitize_includes(args)) if args_valid? args }
  end

  def where(*args)
    clone.tap { |r| r.where_values += args.compact.select { |i| args_valid? i } if args_valid? args }
  end

  def having(*args)
    clone.tap { |r| r.having_values += args if args_valid? args }
  end

  def limit(value = true)
    clone.tap { |r| r.limit_value = value }
  end

  def offset(value = true)
    clone.tap { |r| r.offset_value = value }
  end

  def from(table)
    clone.tap { |r| r.from_value = table }
  end

  def sql(raw_sql)
    clone.tap { |r| r.raw_sql_value = raw_sql }
  end

  protected

  def args_valid?(args)
    args.respond_to?(:empty?) ? !args.empty? : !!args
  end

  # This will allow for the nested structure
  def sanitize_includes(values)
    case values
    when Hash
      values.keys.inject({}) do |hash, key|
        hash.merge key => sanitize_includes(values[key])
      end
    when Array
      values.inject({}) { |hash, val| hash.merge sanitize_includes(val) }
    when String, Symbol
      { values.to_sym => {} }
    else
      {}
    end
  end

end
