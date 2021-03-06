module Perry::Test
  class TestAdapter < Perry::Adapters::AbstractAdapter
    register_as :test

    @@calls = []
    @@writes = []
    @@count = nil
    @@data = nil
    @@last_result = nil
    @@writes_return_value = true

    def read(options)
      query = options[:relation].to_hash
      @@calls << [:read, options, query]
      [].tap do |results|
        (@@count || query[:limit] || 1).times { results << self.data(options[:relation].klass) }
      end.compact
    end

    def write(options)
      c = [:write, options[:object]]
      @@calls << c
      @@writes << c
      writes_return_value
    end

    def delete(options)
      @@calls << [:delete, options[:object]]
      writes_return_value
    end

    def last_call
      @@calls.last
    end

    def last_write
      @@writes.last
    end

    def data(klass=nil)
      if @@data
        @@last_result = (@@data[klass] || @@data).dup.tap do |data_hash|
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

    def writes_return_value
      Perry::Persistence::Response.new({
        :success => @@writes_return_value,
        :parsed => { :id => 1 }
      })
    end

    def reset
      @@calls = []
      @@data = nil
      @@count = nil
      @@writes_return_value = true
      @@writes_use_default_return_value = true
    end

  end
end
