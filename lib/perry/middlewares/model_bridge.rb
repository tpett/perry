class Perry::Middlewares::ModelBridge

  def initialize(adapter, config={})
    @adapter = adapter
    @config = config
  end

  def call(options)
    result = @adapter.call(options)
    if options[:relation]
      build_models_from_records(result, options)
    elsif options[:object]
      result.tap do |response|
        update_model_after_save(response, options[:object])
      end
    else
      result
    end
  end

  protected

  def build_models_from_records(records, options)
    records.collect do |attributes|
      options[:relation].klass.new_from_data_store(attributes)
    end
  end

  def update_model_after_save(response, model)
    model.saved = response.success
    if model.saved
      model.new_record = false
      raise "model does not have primary key attribute" unless model.defined_attributes.include?('id')
      model.id = response.model_attributes[:id] if model.id.nil?
      #model.reload # TODO: also, skip on delete
    end
  end

end
