module Perry

  module Logger
    module ClassMethods

      def log(params, name)
        if block_given?
          result = nil
          ms = Benchmark.measure { result = yield }.real
          log_info(params, name, ms*1000)
          result
        else
          log_info(params, name, 0)
          []
        end
      rescue Exception => err
        log_info(params, name, 0)
        raise
      end

      private

      def log_info(params, name, ms)
        if Perry.logger && Perry.logger.debug?
          name = '%s (%.1fms)' % [name || 'RPC', ms]
          Perry.logger.debug(format_log_entry(name, params.inspect))
        end
      end

      def format_log_entry(message, dump=nil)
        message_color, dump_color = "4;33;1", "0;1"

        log_entry = "  \e[#{message_color}m#{message}\e[0m   "
        log_entry << "\e[#{dump_color}m%#{String === dump ? 's' : 'p'}\e[0m" % dump if dump
        log_entry
      end

    end

    module InstanceMethods

      def log(*args, &block)
        self.class.send(:log, *args, &block)
      end
    end

    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end

end
