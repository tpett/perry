module Perry::Persistence
  class Response
    ATTRIBUTES = [:success, :status, :meta, :raw, :format, :model_attributes, :errors]
    attr_accessor *ATTRIBUTES

    def initialize(attrs={})
      ATTRIBUTES.each do |attr|
        self.send("#{attr}=", attrs[attr])
      end
    end

    def model_attributes
      @model_attributes ||= {}
    end

    def errors
      @errors ||= []
    end
  end
end
