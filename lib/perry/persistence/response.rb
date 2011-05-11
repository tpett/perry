module Perry::Persistence
  class Response

    @@parsers = { :json => ::JSON }
    ATTRIBUTES = [:success, :status, :meta, :raw, :raw_format, :parsed]

    # A boolean value reflecting whether or not the response was successful
    attr_accessor :success

    # A more detailed report of the success/failure of the response
    attr_accessor :status

    # Any adapter specific response metadata
    attr_accessor :meta

    # Raw response -- format specified by raw_format
    attr_accessor :raw

    # Format of the raw response
    attr_accessor :raw_format

    # Parsed raw data
    attr_writer :parsed

    # @attrs: Sets any values listed in ATTRIBUTES
    def initialize(attrs={})
      ATTRIBUTES.each do |attr|
        self.send("#{attr}=", attrs[attr])
      end
    end

    def parsed
      if parser = self.class.parsers[self.raw_format]
        @parsed ||= parser.parse(self.raw)
      else
        @parsed
      end
    end

    def self.parsers
      @@parsers
    end

    def model_attributes
      # return the inner hash if nested
      if parsed_hash.keys.size == 1 && parsed_hash[parsed_hash.keys.first].is_a?(Hash)
        parsed_hash[parsed_hash.keys.first]
      else
        parsed_hash
      end.symbolize_keys
    end

    def errors
      parsed_hash.symbolize_keys
    end

    protected

    def parsed_hash
      if parsed.is_a?(Hash)
        parsed
      else
        {}
      end
    end

  end
end

