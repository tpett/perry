class Perry::Middlewares::ModelBridge

  def initialize(adapter, config={})
    @adapter = adapter
    @config = config
  end

  def call(options)
    result = @adapter.call(options)
    if options[:relation]
      result.collect do |attributes|
        options[:relation].klass.new_from_data_store(attributes)
      end
    else
      result
    end
  end

end

