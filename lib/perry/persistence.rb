require 'perry/persistence/response'

module Perry::Persistence

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
      raise Perry::PerryError.new("cannot write a frozen object") if frozen?
      write_adapter.call(:write, :object => self).success
    end

    def save!
      save or raise Perry::RecordNotSaved
    end

    def update_attributes(attributes)
      self.attributes = attributes
      save
    end

    def update_attributes!(attributes)
      update_attributes(attributes) or raise Perry::RecordNotSaved
    end

    def destroy
      raise Perry::PerryError.new("cannot destroy a frozen object") if frozen?
      unless self.new_record? || self.send(primary_key).nil?
        write_adapter.call(:delete, :object => self).success
      end
    end
    alias :delete :destroy

    def reload
      self.attributes = self.class.where(primary_key => self.send(primary_key)).first.attributes
    end

    # Calls Object#freeze on the model and on the attributes hash in addition to
    # calling #freeze! to prevent the model from being saved or destroyed.
    #
    def freeze
      freeze!
      attributes.freeze
      super
    end

    # Prevents the model from being saved or destroyed in the future while still
    # allowing the model and its attributes hash to be modified.
    #
    def freeze!
      @frozen = true
    end

    # Returns true if ether #freeze or #freeze! has been called on the model.
    #
    def frozen?
      !!@frozen
    end

  end

  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end

end

