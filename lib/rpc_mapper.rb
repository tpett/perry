module RPCMapper
  @@log_file = nil

  def self.logger
    @@logger ||= default_logger
  end

  def self.logger=(logger)
    @@logger = logger
  end

  def self.log_file=(file)
    @@log_file = file
  end

  def self.default_logger
    if defined?(Rails)
      Rails.logger
    else
      require 'logger' unless defined?(::Logger)
      ::Logger.new(@@log_file)
    end
  end

end

require 'rpc_mapper/base'
