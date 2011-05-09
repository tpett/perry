module Perry::Test
  class MiddlewareAdapter < TestAdapter
    alias :call :read
  end
end
