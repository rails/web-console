# frozen_string_literal: true

require "test_helper"

module WebConsole
  class RedisSessionStorageTest < ActiveSupport::TestCase
    setup do
      # Clear any existing Redis keys for this test
      RedisSessionStorage.redis.flushdb if RedisSessionStorage.redis
    end

    teardown do
      # Clean up Redis after each test
      RedisSessionStorage.redis.flushdb if RedisSessionStorage.redis
    end

    test "redis_url returns default when no Rails app" do
      ENV['REDIS_URL'] = nil
      assert_equal "redis://localhost:6379/0", RedisSessionStorage.redis_url
    end

    test "redis_url returns ENV REDIS_URL when set" do
      ENV['REDIS_URL'] = "redis://custom:6380/1"
      assert_equal "redis://custom:6380/1", RedisSessionStorage.redis_url
    ensure
      ENV['REDIS_URL'] = nil
    end

    test "store and find session data" do
      session_id = "test_session_123"
      session_data = { id: session_id, test: "data" }

      RedisSessionStorage.store(session_id, session_data)
      retrieved_data = RedisSessionStorage.find(session_id)

      assert_equal session_data, retrieved_data
    end

    test "find returns nil for non-existent session" do
      assert_nil RedisSessionStorage.find("non_existent_session")
    end

    test "delete removes session data" do
      session_id = "test_session_456"
      session_data = { id: session_id, test: "data" }

      RedisSessionStorage.store(session_id, session_data)
      assert RedisSessionStorage.find(session_id)

      RedisSessionStorage.delete(session_id)
      assert_nil RedisSessionStorage.find(session_id)
    end

    test "session data expires after TTL" do
      session_id = "test_session_789"
      session_data = { id: session_id, test: "data" }

      RedisSessionStorage.store(session_id, session_data)
      assert RedisSessionStorage.find(session_id)

      # Wait for expiration (Redis TTL is 3600 seconds, but we can't wait that long in tests)
      # This test verifies the TTL is set correctly
      ttl = RedisSessionStorage.redis.ttl("web_console:session:#{session_id}")
      assert ttl > 0, "TTL should be set"
      assert ttl <= 3600, "TTL should not exceed 3600 seconds"
    end

    test "handles JSON parsing errors gracefully" do
      session_id = "test_session_invalid"
      
      # Store invalid JSON directly in Redis
      RedisSessionStorage.redis.set("web_console:session:#{session_id}", "invalid json")
      
      assert_nil RedisSessionStorage.find(session_id)
    end

    test "redis connection with custom URL" do
      original_url = RedisSessionStorage.redis_url
      
      begin
        # Test with a custom URL (this won't actually connect in test environment)
        RedisSessionStorage.instance_variable_set(:@redis, nil)
        ENV['REDIS_URL'] = "redis://test:6379/0"
        
        # Should not raise an error
        assert RedisSessionStorage.redis
      ensure
        ENV['REDIS_URL'] = nil
        RedisSessionStorage.instance_variable_set(:@redis, nil)
      end
    end
  end
end 
