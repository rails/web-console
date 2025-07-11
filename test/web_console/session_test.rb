# frozen_string_literal: true

require "test_helper"

module WebConsole
  class SessionTest < ActiveSupport::TestCase
    class ValueAwareError < StandardError
      def self.raise(value)
        ::Kernel.raise self, value
      rescue => exc
        exc
      end

      def self.raise_nested_error(value)
        ::Kernel.raise self, value
      rescue
        value = 1 # Override value so we can target the binding here
        ::Kernel.raise "Second Error" rescue $!
      end

      attr_reader :value

      def initialize(value)
        @value = value
      end
    end

    setup do
      Session.inmemory_storage.clear
      @session = Session.new([[binding]])
    end

    test "returns nil when a session is not found" do
      assert_nil Session.find("nonexistent session")
    end

    test "find returns a persisted object" do
      assert_equal @session, Session.find(@session.id)
    end

    test "can evaluate code in the currently selected binding" do
      assert_equal "=> 42\n", @session.eval("40 + 2")
    end

    test "use first binding if no application bindings" do
      binding = Object.new.instance_eval do
        def eval(string)
          case string
          when "__FILE__" then framework
          when "called?" then "yes"
          end
        end

        def source_location
        end

        self
      end

      session = Session.new([[binding]])
      assert_equal session.eval("called?"), "=> \"yes\"\n"
    end

    test "#from can create session from a single binding" do
      value, saved_binding = __LINE__, binding
      Thread.current[:__web_console_binding] = saved_binding

      session = Session.from(__web_console_binding: saved_binding)

      assert_equal "=> #{value}\n", session.eval("value")
    end

    test "#from can create session from an exception" do
      value = __LINE__
      exc = ValueAwareError.raise(value)

      session = Session.from(__web_console_exception: exc)

      assert_equal "=> #{exc.value}\n", session.eval("value")
    end

    test "#from can switch to bindings" do
      value = __LINE__
      exc = ValueAwareError.raise(value)

      session = Session.from(__web_console_exception: exc)
      session.switch_binding_to(1, exc.object_id)

      assert_equal "=> #{value}\n", session.eval("value")
    end

    test "#from can switch to the cause" do
      value = __LINE__
      exc = ValueAwareError.raise_nested_error(value)

      session = Session.from(__web_console_exception: exc)
      session.switch_binding_to(1, exc.cause.object_id)

      assert_equal "=> #{value}\n", session.eval("value")
    end

    test "#from prioritizes exceptions over bindings" do
      exc = ValueAwareError.raise(42)

      session = Session.from(__web_console_exception: exc, __web_console_binding: binding)

      assert_equal "=> WebConsole::SessionTest::ValueAwareError\n", session.eval("self")
    end

    # Redis session storage tests
    test "stores session in Redis when use_redis_storage is true" do
      Session.use_redis_storage = true
      
      session = Session.new([[binding]])
      
      # Verify session is stored in Redis
      redis_data = RedisSessionStorage.find(session.id)
      assert redis_data
      assert_equal session.id, redis_data[:id]
    end

    test "does not store session in Redis when use_redis_storage is false" do
      Session.use_redis_storage = false
      
      session = Session.new([[binding]])
      
      # Verify session is not stored in Redis
      redis_data = RedisSessionStorage.find(session.id)
      assert_nil redis_data
    end

    test "can find session from Redis when use_redis_storage is true" do
      Session.use_redis_storage = true
      
      # Create a session that gets stored in Redis
      original_session = Session.new([[binding]])
      session_id = original_session.id
      
      # Clear in-memory storage to simulate different process
      Session.inmemory_storage.clear
      
      # Find session from Redis
      found_session = Session.find(session_id)
      assert found_session
      assert_equal session_id, found_session.id
    end

    test "handles Redis connection errors gracefully" do
      Session.use_redis_storage = true
      
      # Mock Redis to raise an error
      RedisSessionStorage.stubs(:find).raises(Redis::BaseConnectionError.new("Connection failed"))
      
      # Should return nil instead of raising an error
      assert_nil Session.find("some_session_id")
    end

    test "handles Redis storage errors gracefully" do
      Session.use_redis_storage = true
      
      # Mock Redis to raise an error during storage
      RedisSessionStorage.stubs(:store).raises(Redis::BaseConnectionError.new("Connection failed"))
      
      # Should not raise an error when creating session
      assert_nothing_raised do
        Session.new([[binding]])
      end
    end
  end
end
