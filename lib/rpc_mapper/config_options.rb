module RPCMapper

  module ConfigOptions
    module ClassMethods

      def config_options(options={})
        options.each do |option, default_value|
          class_eval do
            self.configure_options << option
            class_inheritable_accessor option
            self.send "#{option}=", default_value
          end
          # TRP: We run a direct string eval on the class because we cannot get a closure on the class << self scope
          #      We need that in order to use our option variable to define a class method of the same name.
          self.class_eval <<-EOS
            def self.#{option}                                                              # def self.my_awesome_option
              val = read_inheritable_attribute(:#{option})                                  #   val = read_inheritable_attribute(:my_awesome_option)
              val.is_a?(Proc) ? write_inheritable_attribute(:#{option}, val.call) : val     #   val.is_a?(Proc) ? write_inheritable_attribute(:my_awesome_option, val.call) : val
            end                                                                             # end
          EOS
        end
      end

    end

    module InstanceMethods

    end

    def self.included(receiver)
      receiver.class_eval do
        class_inheritable_accessor :configure_options
        self.configure_options = []
      end

      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end

end