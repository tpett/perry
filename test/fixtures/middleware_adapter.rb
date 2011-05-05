module Perry::Test
  class MiddlewareAdapter < TestAdapter
    def call(options)
      []
    end
  end
end
