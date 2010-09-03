module RPCMapper::Test
  class TestAdapter < RPCMapper::Adapters::AbstractAdapter
    register_as :test

    attr_accessor :calls, :data, :count

    def call(procedure, options={})
      self.calls << [procedure, options]
      log(options, "TEST #{procedure}")

      # TRP: Build up the fake data
      result = []
      (@count || options[:limit] || 1).times { result << data }
      result
    end

    def last_call
      calls.last
    end

    def calls
      @calls ||= []
    end

    def reset
      @calls = []
      @data = nil
      @count = nil
    end

  end
end
