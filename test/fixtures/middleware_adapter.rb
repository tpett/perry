module Perry::Test
  class MiddlewareAdapter < TestAdapter

    # Allows us to test a single middleware without having to setup an entire middleware stack
    def call(options)
      self.method(self.type).call(options)
    end
  end
end
