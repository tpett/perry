module RPCMapper::Test
  class TestAdapter < RPCMapper::Adapters::AbstractAdapter
    register_as :test

    @@calls = []
    @@count = nil
    @@data = nil

    def read(options)
      @@calls << [:read, options]
      [].tap { |results| (@@count || options[:limit] || 1).times { results << data } }.compact
    end

    def write(object)
      @@calls << [:write, object]
      true
    end

    def delete(object)
      @@calls << [:delete, object]
      true
    end

    def last_call
      @@calls.last
    end

    def data
      @@data
    end

    def data=(data)
      @@data = data
    end

    def count=(count)
      @@count = count
    end

    def calls
      @@calls
    end

    def reset
      @@calls = []
      @@data = nil
      @@count = nil
    end

  end
end
