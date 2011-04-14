require 'perry/scopes/conditions'

module Perry::Scopes
  
  module ClassMethods
    
    def scopes
      read_inheritable_attribute(:scopes) || write_inheritable_attribute(:scopes, {})
    end
    
    def scoped
      current_scope ? relation.merge(current_scope) : relation.clone
    end
    
    def scope(name, scope_options={})
      name = name.to_sym
      
      # TRP: Define the scope and merge onto the relation
      scopes[name] = lambda do |*args|
        options = scope_options.is_a?(Proc) ? scope_options.call(*args) : scope_options
        if options.is_a?(Hash)
          scoped.apply_finder_options(options)
        else
          scoped.merge(options)
        end
      end
      
      # TRP: Bind the above block to a method for easy access
      singleton_class.send(:define_method, name, &scopes[name])
    end
    
  end
  
  module InstanceMethods
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
    
    receiver.extend Conditions
  end
  
end
