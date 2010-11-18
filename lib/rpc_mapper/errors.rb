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

  # Raised when trying to eager load an association that relies on instance level data.
  # class Article < RPCMapper::Base
  #   has_many :comments, :conditions => lambda { |article| ... }
  # end
  #
  # Article.recent.includes(:comments) # Raises AssociationPreloadNotSupported
  class AssociationPreloadNotSupported < RPCMapperError
  end

end
