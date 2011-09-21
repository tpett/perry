module Perry::Support; end

module Perry::Support::ClassAttributes

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods

    def class_attribute(*attrs)
      @class_attributes ||= []
      @class_attributes += attrs
      attrs.each do |attr|
        class_eval %{
          def self.#{attr}
            @#{attr}
          end
          def self.#{attr}=(value = nil)
            @#{attr} = value
          end
          def #{attr}
            self.class.#{attr}
          end
          def #{attr}=(value = nil)
            self.class.#{attr} = value
          end
        }
      end
      @class_attributes
    end
    alias :class_attributes :class_attribute

    def inherited(subclass)
      (["class_attributes"] + class_attributes).each do |t|
        ivar = "@#{t}"
        value = instance_variable_get(ivar)
        subclass.instance_variable_set(
          ivar,
          value.duplicable? ? value.dup : value
        )
      end
    end

  end

end

