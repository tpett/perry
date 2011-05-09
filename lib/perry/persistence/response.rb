module Perry::Persistence
  class Response
    attr_accessor :success, :status, :meta, :raw, :format, :model_attributes, :errors
  end
end
