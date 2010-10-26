module RPCMapper

  # Generic RPCMapper error
  class RPCMapperError < StandardError
  end

  # Raised when RPCMapper cannot find records from a given id or set of ids
  class RecordNotFound < RPCMapperError
  end

  # Raised when RPCMapper cannot save a record through the write_adapter and save! or update_attributes! was used
  class RecordNotSaved < RPCMapperError
  end

end
