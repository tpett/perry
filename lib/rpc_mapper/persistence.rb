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

    def save!
      save or raise RPCMapper::RecordNotSaved
    end

    def update_attributes(attributes)
      self.attributes = attributes
      save
    end

    def update_attributes!(attributes)
      update_attributes(attributes) or raise RPCMapper::RecordNotSaved
    end

    def destroy
      write_adapter.delete(self) unless self.new_record?
    end
    alias :delete :destroy

  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end
