# frozen_string_literal: true

require "redis"
require "json"

module WebConsole
  # Redis-based session storage for web-console
  # This fixes the "Session is no longer available in memory" error
  # when using multi-process servers like Puma or Unicorn
  class RedisSessionStorage
    class << self
      def redis
        @redis ||= begin
          url = redis_url
          Redis.new(url: url, reconnect_attempts: 3, timeout: 5)
        end
      end

      def redis_url
        if defined?(Rails) && Rails.application
          if Rails.application.respond_to?(:secrets) && Rails.application.secrets.respond_to?(:[]) && Rails.application.secrets[:redis_url]
            Rails.application.secrets[:redis_url]
          else
            ENV['REDIS_CONNECTION_URL_DEV'] || \
            ENV['REDIS_CONNECTION_URL_PRO'] || \
            ENV['REDIS_URL'] || "redis://localhost:6379/0"
          end
        else
          ENV['REDIS_URL'] || "redis://localhost:6379/0"
        end
      end

      def store(id, session_data)
        redis.setex("web_console:session:#{id}", 3600, session_data.to_json)
      end

      def find(id)
        data = redis.get("web_console:session:#{id}")
        return nil unless data

        begin
          JSON.parse(data, symbolize_names: true)
        rescue JSON::ParserError
          nil
        end
      end

      def delete(id)
        redis.del("web_console:session:#{id}")
      end

      def cleanup_expired
        # Redis automatically expires keys, so no manual cleanup needed
      end
    end
  end
end
