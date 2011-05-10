module Perry::Persistence
  class Response
    ATTRIBUTES = [:success, :status, :meta, :raw, :format, :model_attributes, :errors]
    attr_accessor *ATTRIBUTES

    def initialize(attrs={})
      ATTRIBUTES.each do |attr|
        self.send("#{attr}=", attrs[attr])
      end
    end
  end
end
