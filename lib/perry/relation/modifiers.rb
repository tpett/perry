module Perry::Modifiers
  attr_accessor :modifiers_value, :modifiers_array

  # The modifiers query method allows you to 'extend' your query by adding parameters that
  # middlewares or adapters can use to modify the query itself or modify how the query is executed.
  # This method expects a hash or a Proc that returns a hash as its only argument and will merge
  # that hash onto a master hash of query modifiers.
  #
  # For most purposes, the modifiers method acts like any other query method. For example, you
  # can chain it with other query methods on a relation, and you can build scopes with it.
  # One exception is that modifiers are not included in the hash returned by Relation#to_hash.
  # This exception is intended to discourage adapters from passing modifiers to backends external
  # to perry (such as a data server or a webservice call) whose behavior is undefined with respect
  # to these additional parameters/
  #
  # See also 'perry/middlewares/cache_records/scopes.rb' for examples of how to use the modifiers
  # pseudo-query method.
  def modifiers(value={})
    clone.tap do |r|
      if value.nil?
        r.modifiers_array = [] # wipeout all previously set modifiers
      else
        r.modifiers_array ||= []
        r.modifiers_array.push(value)
      end
    end
  end

  def modifiers_value
    self.modifiers_array ||= []
    {}.tap do |hash|
      self.modifiers_array.each do |value|
        hash.merge!(value.is_a?(Proc) ? value.call : value)
      end
    end
  end
end
