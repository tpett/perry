require 'rpc_mapper/relation/query_methods'
require 'rpc_mapper/relation/finder_methods'

# TRP: The concepts behind this class are heavily influenced by ActiveRecord::Relation v.3.0.0RC1
# => http://github.com/rails/rails
# Used to achieve the chainability of scopes -- methods are delegated back and forth from BM::Base and BM::Relation
class RPCMapper::Relation
  attr_reader :klass
  attr_accessor :records

  SINGLE_VALUE_METHODS = [:limit, :offset, :from, :fresh]
  MULTI_VALUE_METHODS = [:select, :group, :order, :joins, :includes, :where, :having]

  FINDER_OPTIONS = SINGLE_VALUE_METHODS + MULTI_VALUE_METHODS + [:conditions, :search, :sql]

  include RPCMapper::QueryMethods
  include RPCMapper::FinderMethods

  def initialize(klass)
    @klass = klass

    SINGLE_VALUE_METHODS.each {|v| instance_variable_set(:"@#{v}_value", nil)}
    MULTI_VALUE_METHODS.each {|v| instance_variable_set(:"@#{v}_values", [])}
  end

  def merge(r)
    merged_relation = clone
    return merged_relation unless r

    SINGLE_VALUE_METHODS.each do |option|
      new_value = r.send("#{option}_value")
      merged_relation = merged_relation.send(option, new_value) if new_value
    end

    MULTI_VALUE_METHODS.each do |option|
      merged_relation = merged_relation.send(option, *r.send("#{option}_values"))
    end

    merged_relation
  end

  def to_hash
    # TRP: If present pass :sql option alone as it trumps all other options
    @hash ||= if self.raw_sql_value
      { :sql => raw_sql_value }
    else
      hash = SINGLE_VALUE_METHODS.inject({}) do |h, option|
        value = self.send("#{option}_value")
        value ? h.merge(option => value) : h
      end

      hash.merge!((MULTI_VALUE_METHODS - [:select]).inject({}) do |h, option|
        value = self.send("#{option}_values")
        value && !value.empty? ? h.merge(option => value.uniq) : h
      end)

      # TRP: If one of the select options contains a * than select options are ignored
      if select_values && !select_values.empty? && !select_values.any? { |val| val.to_s.match(/\*$/) }
        hash.merge!(:select => select_values.uniq)
      end

      hash
    end
  end

  def reset_queries
    @hash = nil
    @records = nil
  end

  def to_a
    @records ||= fetch_records
  end

  def eager_load?
    @includes_values && !@includes_values.empty?
  end

  def inspect
   to_a.inspect
  end

  def scoping
    @klass.scoped_methods << self
    begin
      yield
    ensure
      @klass.scoped_methods.pop
    end
  end

  def respond_to?(method, include_private=false)
    super ||
    Array.method_defined?(method) ||
    @klass.scopes[method] ||
    dynamic_finder_method(method) ||
    @klass.respond_to?(method, false)
  end

  def dynamic_finder_method(method)
    defined_attributes = (@klass.defined_attributes || []).join('|')
    if method.to_s =~ /^(find_by|find_all_by)_(#{defined_attributes})/
      [$1, $2]
    else
      nil
    end
  end

  protected

  def method_missing(method, *args, &block)
    if Array.method_defined?(method)
      to_a.send(method, *args, &block)
    elsif result = dynamic_finder_method(method)
      method, attribute = result
      options = { :conditions => { attribute => args[0] } }
      options.merge!(args[1]) if args[1] && args[1].is_a?(Hash)
      case method.to_sym
      when :find_by
        self.first(options)
      when :find_all_by
        self.all(options)
      end
    elsif @klass.scopes[method]
      merge(@klass.send(method, *args, &block))
    elsif @klass.respond_to?(method, false)
      scoping { @klass.send(method, *args, &block) }
    else
      super
    end
  end

  def fetch_records
    @klass.send(:fetch_records, self)
  end

end
