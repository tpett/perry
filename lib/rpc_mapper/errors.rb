module RPCMapper

  # Generic RPCMapper error
  class RPCMapperError < StandardError
  end

  # Raised when RPCMapper cannot find records from a given id or set of ids
  class RecordNotFound < RPCMapperError
  end

  # TODO:
  # # Raised when RPCMapper cannot save a record through the mutable adapter
  # class RecordNotSaved < RPCMapperError
  # end

end
