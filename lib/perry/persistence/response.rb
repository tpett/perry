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
        begin
          @parsed ||= parser.parse(self.raw)
        rescue Exception => err
          Perry.logger.error("Failure parsing raw response #{err.inspect}")
          Perry.logger.error("Response: #{self.inspect}")
          nil
        end
      else
        @parsed
      end
    end

    def self.parsers
      @@parsers
    end

    def model_attributes
      # return the inner hash if nested
      extract_attributes(parsed_hash)
    end

    def array_attributes
      if parsed.is_a?(Array)
        parsed.collect { |item| item.is_a?(Hash) ? extract_attributes(item) : item }
      else
        []
      end
    end

    def errors
      parsed_hash.symbolize_keys
    end

    protected

    def extract_attributes(hash)
      if hash.keys.size == 1 && hash[hash.keys.first].is_a?(Hash)
        hash[hash.keys.first]
      else
        hash
      end.symbolize_keys
    end

    def parsed_hash
      if parsed.is_a?(Hash)
        parsed
      else
        {}
      end
    end

  end
end

