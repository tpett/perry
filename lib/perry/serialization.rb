require 'yaml'

module Perry::Serialization

  module ClassMethods

    def serialize(fields)
      [*fields].each do |field|
        serialized_attributes << field

        define_method("deserialize_#{field}") do
          YAML.load(self[field]) rescue self[field]
        end

        alias_method "#{field}_raw", field
        alias_method field, "deserialize_#{field}"

        set_serialize_writers(field) if self.write_adapter

      end
    end

    def set_serialize_writers(field)
      define_method("serialize_#{field}") do |value|
        self[field] = value.to_yaml
      end

      alias_method "#{field}_raw=", "#{field}="
      alias_method "#{field}=", "serialize_#{field}"
    end

  end

  module InstanceMethods

  end

  def self.included(receiver)
    receiver.class_eval do
      class_inheritable_accessor :serialized_attributes
      self.serialized_attributes = []
    end

    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end