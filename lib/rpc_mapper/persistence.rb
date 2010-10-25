module RPCMapper::Persistence

  module ClassMethods

    protected

    def create_writer(attribute)
      define_method("#{attribute}=") do |value|
        self[attribute] = value
      end
    end

  end


  module InstanceMethods

    def []=(attribute, value)
      set_attribute(attribute, value)
    end

    def attributes=(attributes)
      set_attributes(attributes)
    end

    def save
      write_adapter.write(self)
    end

    def update_attributes(attributes)
      self.attributes = attributes
      save
    end

    def destroy
      write_adapter.delete(self)
    end
    alias :delete :destroy

  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end
