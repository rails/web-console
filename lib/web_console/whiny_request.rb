# frozen_string_literal: true

module WebConsole
  # Noisy wrapper around +Request+.
  #
  # If any calls to +permitted?+ and +acceptable_content_type?+
  # return false, an info log message will be displayed in users' logs.
  class WhinyRequest < SimpleDelegator
    def permitted?(allow_all_connections_from_any_ip = false)
      whine_unless(request.permitted?(allow_all_connections_from_any_ip))  do
        "Cannot render console from #{request.strict_remote_ip}! " \
          "Allowed networks: #{request.permissions}"
      end
    end

    private

      def whine_unless(condition)
        unless condition
          logger.info { yield }
        end
        condition
      end

      def logger
        env["action_dispatch.logger"] || WebConsole.logger
      end

      def request
        __getobj__
      end
  end
end
