class Perry::Middlewares::ModelBridge

  def initialize(adapter, config={})
    @adapter = adapter
    @config = config
  end

  def call(options)
    result = @adapter.call(options)

    case options[:mode]
    when :read
      build_models_from_records(result, options)
    when :write
      update_model_after_save(result, options[:object])
      result
    when :delete
      update_model_after_delete(result, options[:object])
      result
    else
      result
    end
  end

  protected

  def build_models_from_records(records, options)
    if options[:relation] && records
      records.collect do |attributes|
        options[:relation].klass.new_from_data_store(attributes)
      end
    else
      records
    end
  end

  def update_model_after_save(response, model)
    model.saved = response.success
    if model.saved
      if model.new_record? && model.read_adapter
        key = response.model_attributes[model.primary_key]
        raise Perry::PerryError.new('primary key not included in response') if key.nil?
        model.send("#{model.primary_key}=", key)
      end
      model.new_record = false
      model.reload unless model.read_adapter.nil?
    else
      add_errors_to_model(response, model, 'not saved')
    end
  end

  def update_model_after_delete(response, model)
    if response.success
      model.freeze!
    else
      add_errors_to_model(response, model, 'not deleted')
    end
  end

  def add_errors_to_model(response, model, default_message)
    errors = response.errors
    errors[:base] = default_message if errors.empty?
    model.errors.merge!(errors)
  end

end
