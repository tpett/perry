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
      result.tap { |response| update_model_after_save(response, options[:object]) }
    else
      result
    end
  end

  protected

  def build_models_from_records(records, options)
    if options[:relation]
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
      if model.new_record?
        key = response.model_attributes[:id]
        raise Perry::PerryError.new('primary key not included in response') if key.nil?
        model.id = key
      end
      model.new_record = false
      model.reload unless model.read_adapter.nil?
    else
      errors = response.errors
      errors[:base] = 'not saved' if errors.empty?
      model.errors.merge!(errors)
    end
  end

end
