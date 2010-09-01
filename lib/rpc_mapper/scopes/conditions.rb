
# TRP: Implementation of this feature was heavily influenced by binarylogic's Searchlogic-2.4.19
# => http://github.com/binarylogic/searchlogic
#
#  It is designed to mimick much of the API of searchlogic so that it can be used alongside AR objects utilizing Searchlogic
#  without developer confusion.  There are certain features that are skipped because of the nature of RPCMapper.

module RPCMapper::Scopes

  module Conditions

    COMPARISON_CONDITIONS = {
      :equals => [:is, :eq],
      :does_not_equal => [:not_equal_to, :is_not, :not, :ne],
      :less_than => [:lt, :before],
      :less_than_or_equal_to => [:lte],
      :greater_than => [:gt, :after],
      :greater_than_or_equal_to => [:gte],
    }

    WILDCARD_CONDITIONS = {
      :like => [:contains, :includes],
      :not_like => [:does_not_include],
      :begins_with => [:bw],
      :not_begin_with => [:does_not_begin_with],
      :ends_with => [:ew],
      :not_end_with => [:does_not_end_with]
    }

    CONDITIONS = {}

    # Add any / all variations to every comparison and wildcard condition
    COMPARISON_CONDITIONS.merge(WILDCARD_CONDITIONS).each do |condition, aliases|
      CONDITIONS[condition] = aliases
      CONDITIONS["#{condition}_any".to_sym] = aliases.collect { |a| "#{a}_any".to_sym }
      CONDITIONS["#{condition}_all".to_sym] = aliases.collect { |a| "#{a}_all".to_sym }
    end

    CONDITIONS[:equals_any] = CONDITIONS[:equals_any] + [:in]
    CONDITIONS[:does_not_equal_all] = CONDITIONS[:does_not_equal_all] + [:not_in]

    PRIMARY_CONDITIONS = CONDITIONS.keys
    ALIAS_CONDITIONS = CONDITIONS.values.flatten

    def respond_to?(name, include_private=false)
      super ||
      condition_details(name)
    end

    private

    def method_missing(name, *args, &block)
      if details = condition_details(name)
        create_condition(details[:attribute], details[:condition], args)
        send(name, *args)
      else
        super
      end
    end

    def condition_details(method_name)
      return nil unless defined_attributes

      attribute_name_matcher = defined_attributes.join("|")
      conditions_matcher = (PRIMARY_CONDITIONS + ALIAS_CONDITIONS).join("|")

      if method_name.to_s =~ /^(#{attribute_name_matcher})_(#{conditions_matcher})$/
        {:attribute => $1, :condition => $2}
      end
    end

    def create_condition(attribute, condition, args)
      if PRIMARY_CONDITIONS.include?(condition.to_sym)
        create_primary_condition(attribute, condition)
      elsif ALIAS_CONDITIONS.include?(condition.to_sym)
        create_alias_condition(attribute, condition, args)
      end
    end

    def create_primary_condition(attribute, condition)
      scope_name = "#{attribute}_#{condition}"
      scope scope_name, lambda { |a| where(scope_name => a) }
    end

    def create_alias_condition(attribute, condition, args)
      primary_condition = primary_condition(condition)
      alias_name = "#{attribute}_#{condition}"
      primary_name = "#{attribute}_#{primary_condition}"
      send(primary_name, *args) # go back to method_missing and make sure we create the method
      singleton_class.class_eval { alias_method alias_name, primary_name }
    end

    # Returns the primary condition for the given alias. Ex:
    #
    #   primary_condition(:gt) => :greater_than
    def primary_condition(alias_condition)
      CONDITIONS.find { |k, v| k == alias_condition.to_sym || v.include?(alias_condition.to_sym) }.first
    end
  end

end
