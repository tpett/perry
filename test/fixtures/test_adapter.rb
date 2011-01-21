module RPCMapper::Test
  class TestAdapter < RPCMapper::Adapters::AbstractAdapter
    register_as :test

    @@calls = []
    @@count = nil
    @@data = nil
    @@last_result = nil
    @@writes_return_value = true

    def read(options)
      @@calls << [:read, options]
      [].tap do |results|
        (@@count || options[:limit] || 1).times { results << self.data }
      end.compact
    end

    def write(object)
      @@calls << [:write, object]
      @@writes_return_value
    end

    def delete(object)
      @@calls << [:delete, object]
      @@writes_return_value
    end

    def last_call
      @@calls.last
    end

    def data
      if @@data
        @@last_result = @@data.dup.tap do |data_hash|
          data_hash.each do |key, value|
            data_hash[key] = value.call(@@last_result) if value.is_a?(Proc)
          end
        end
      else
        nil
      end
    end

    def data=(data)
      @@last_result = nil
      @@data = data
    end

    def count=(count)
      @@count = count
    end

    def count
      @@count
    end

    def calls
      @@calls
    end

    def writes_return(val)
      @@writes_return_value = val
    end

    def reset
      @@calls = []
      @@data = nil
      @@count = nil
      @@writes_return_value = true
    end

  end
end
