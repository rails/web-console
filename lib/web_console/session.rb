# frozen_string_literal: true

module WebConsole
  # A session lets you persist an +Evaluator+ instance in memory associated
  # with multiple bindings.
  #
  # Each newly created session is persisted into memory and you can find it
  # later by its +id+.
  #
  # A session may be associated with multiple bindings. This is used by the
  # error pages only, as currently, this is the only client that needs to do
  # that.
  class Session
    cattr_reader :inmemory_storage, default: {}
    cattr_accessor :use_redis_storage, default: true

    class << self
      # Finds a persisted session in memory by its id.
      #
      # Returns a persisted session if found in memory.
      # Raises NotFound error unless found in memory.
      def find(id)
        if use_redis_storage
          find_in_redis(id)
        else
          inmemory_storage[id]
        end
      end

      # Find a session in Redis storage
      def find_in_redis(id)
        session_data = RedisSessionStorage.find(id)
        return nil unless session_data

        # Reconstruct the session from stored data
        reconstruct_session_from_data(session_data)
      rescue => e
        WebConsole.logger.error("Failed to retrieve session from Redis: #{e.message}")
        nil
      end

      # Create a Session from an binding or exception in a storage.
      #
      # The storage is expected to respond to #[]. The binding is expected in
      # :__web_console_binding and the exception in :__web_console_exception.
      #
      # Can return nil, if no binding or exception have been preserved in the
      # storage.
      def from(storage)
        if exc = storage[:__web_console_exception]
          new(ExceptionMapper.follow(exc))
        elsif binding = storage[:__web_console_binding]
          new([[binding]])
        end
      end

      private

        def reconstruct_session_from_data(session_data)
          # Create a new session with the stored exception mappers
          exception_mappers = session_data[:exception_mappers].map do |mapper_data|
            ExceptionMapper.new(mapper_data[:exception])
          end

          session = new(exception_mappers)
          session.instance_variable_set(:@id, session_data[:id])
          session
        end
    end

    # An unique identifier for every REPL.
    attr_reader :id

    def initialize(exception_mappers)
      @id = SecureRandom.hex(16)

      @exception_mappers = exception_mappers
      @evaluator         = Evaluator.new(@current_binding = exception_mappers.first.first)

      store_into_memory
      store_into_redis if self.class.use_redis_storage
    end

    # Evaluate +input+ on the current Evaluator associated binding.
    #
    # Returns a string of the Evaluator output.
    def eval(input)
      @evaluator.eval(input)
    end

    # Switches the current binding to the one at specified +index+.
    #
    # Returns nothing.
    def switch_binding_to(index, exception_object_id)
      bindings = ExceptionMapper.find_binding(@exception_mappers, exception_object_id)

      @evaluator = Evaluator.new(@current_binding = bindings[index.to_i])
    end

    # Returns context of the current binding
    def context(objpath)
      Context.new(@current_binding).extract(objpath)
    end

    private

      def store_into_memory
        inmemory_storage[id] = self
      end

      def store_into_redis
        session_data = {
          id: @id,
          exception_mappers: @exception_mappers.map do |mapper|
            {
              exception: mapper.exc,
              backtrace: mapper.exc.backtrace,
              bindings: mapper.exc.bindings
            }
          end
        }

        RedisSessionStorage.store(@id, session_data)
      rescue => e
        WebConsole.logger.error("Failed to store session in Redis: #{e.message}")
      end
  end
end
