# TRP: Cherry pick some goodies from active_support
require 'active_support/core_ext/array'
require 'active_support/core_ext/class/inheritable_attributes'
require 'active_support/core_ext/hash/deep_merge'
begin
  require 'active_support/core_ext/duplicable' #ActiveSupport 2.3.x
  Hash.send(:include, ActiveSupport::CoreExtensions::Hash::DeepMerge) unless Hash.instance_methods.include?('deep_merge')
rescue LoadError => exception
  require 'active_support/core_ext/object/duplicable' #ActiveSupport 3.0.x
end
require 'active_support/core_ext/module/delegation'

# TRP: Used for pretty logging
autoload :Benchmark, 'benchmark'

require 'ostruct'

# TRP: Perry core_ext
require 'perry/core_ext/kernel/singleton_class'

module Perry
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

require 'perry/base'

