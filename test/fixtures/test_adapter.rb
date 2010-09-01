module RPCMapper::Test
  class TestAdapter < RPCMapper::Adapters::AbstractAdapter
    register_as :test

    attr_accessor :calls, :data

    def call(procedure, options={})
      self.calls << [procedure, options]
      log(options, "TEST #{procedure}")

      # TRP: Build up the fake data
      count = options[:limit] || 1
      result = []
      count.times { result << data }
      result
    end

    def last_call
      calls.last
    end

    def calls
      @calls ||= []
    end

    def data
      @data ||= {}
    end

    def reset
      @calls = []
      @data = {}
    end

  end
end
