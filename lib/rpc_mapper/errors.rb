module RPCMapper

  # Generic RPCMapper error
  #
  class RPCMapperError < StandardError
  end

  # Raised when RPCMapper cannot find records from a given id or set of ids
  #
  class RecordNotFound < RPCMapperError
  end

  # Raised when RPCMapper cannot save a record through the write_adapter
  # and save! or update_attributes! was used
  #
  class RecordNotSaved < RPCMapperError
  end

  # Used for all association related errors
  #
  class AssociationError < RPCMapperError
  end

  # Raised when trying to eager load an association that relies on instance
  # level data.
  # class Article < RPCMapper::Base
  #   has_many :comments, :conditions => lambda { |article| ... }
  # end
  #
  # Article.recent.includes(:comments) # Raises AssociationPreloadNotSupported
  #
  class AssociationPreloadNotSupported < AssociationError
  end

  # Raised when trying to eager load an association that does not exist or
  # trying to create a :has_many_through association with a nonexistant
  # association as the source
  #
  class AssociationNotFound < AssociationError
  end

  # Raised when a polymorphic association type is not present in the specified
  # scope.  Always be sure that any values set for the type attribute on any
  # polymorphic association are real constants defined in :polymorphic_namespace
  #
  class PolymorphicAssociationTypeError < AssociationError
  end

end
