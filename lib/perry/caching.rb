
class Perry::Caching

  ##
  # Resets all registered caching services.  These can be middlewares, processors, adapters, or
  # anything that needs to be called upon a cache reset.
  #
  def self.reset
    registry.each { |method| method.call }
  end

  ##
  # Register a method to be reset
  #
  def self.register(method=nil, &block)
    registry
    @registry << (method || block)
  end

  def self.registry
    @registry ||= []
  end

  ##
  # Return a list of registered methods
  #
  def self.registered
    @registry || []
  end

  ##
  # Enable caching flag
  #
  def self.enable
    @enabled = true
  end

  ##
  # Disable caching flag
  #
  def self.disable
    @enabled = false
  end

  ##
  # Return enabled flag status
  #
  def self.enabled?
    @enabled
  end

  ##
  # Accept a block to use caching in -- cache will be reset after the block and the original state
  # of the enabled flag will be set after the block exits
  #
  def self.use(&block)
    caching_block(true, &block)
  end

  ##
  # Accept a block to NOT cache in -- caching will be disabled for this block and then returned to
  # the previous status.
  #
  def self.forgo(&block)
    caching_block(false, &block)
  end

  def self.clean_registry
    @registry = []
    @enabled = nil
  end

  protected

  def self.caching_block(status)
    initial_status = @enabled
    begin
      @enabled = status
      yield
    ensure
      reset if status
      @enabled = initial_status
    end
  end

end

