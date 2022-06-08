# frozen_string_literal: true

require "test_helper"

module WebConsole
  class MiddlewareTest < ActionDispatch::IntegrationTest
    class Application
      def initialize(options = {})
        @response_content_type = options.fetch(:response_content_type, "text/html")
        @response_content_length = options.fetch(:response_content_length, nil)
      end

      def call(env)
        [ status, headers, body ]
      end

      def body
        @body ||= StringIO.new(<<-HTML.strip_heredoc)
          <html>
            <head>
              <title>Hello world</title>
            </head>
            <body>
              <p id="hello-world">Hello world</p>
            </body>
          </html>
        HTML
      end

      private

        def status
          500
        end

        def headers
          Hash.new.tap do |header_hash|
            header_hash["content-type"] = "#{@response_content_type}; charset=utf-8" unless @response_content_type.nil?
            header_hash["content-length"] = @response_content_length unless @response_content_length.nil?
          end
        end
    end

    setup do
      Thread.current[:__web_console_exception] = nil
      Thread.current[:__web_console_binding] = nil
      Rails.stubs(:root).returns Pathname(__FILE__).parent
      Request.stubs(:permissions).returns(IPAddr.new("0.0.0.0/0"))

      Middleware.mount_point = ""
      @app = Middleware.new(Application.new)
    end

    test "render console in an html application from web_console.binding" do
      Thread.current[:__web_console_binding] = binding

      get "/", params: nil

      assert_select "#console"
    end

    test "render console in an html application from web_console.exception" do
      Thread.current[:__web_console_exception] = raise_exception

      get "/", params: nil

      assert_select "body > #console"
    end

    test "render error_page.js from web_console.exception" do
      Thread.current[:__web_console_exception] = raise_exception

      get "/", params: nil

      assert_select "body > script[data-template=error_page]"
    end

    test "render console if response format is HTML" do
      Thread.current[:__web_console_binding] = binding
      @app = Middleware.new(Application.new(response_content_type: "text/html"))

      get "/", params: nil

      assert_select "#console"
    end

    test "sets correct content-length header" do
      Thread.current[:__web_console_binding] = binding
      @app = Middleware.new(Application.new(response_content_length: 7))

      get "/", params: nil

      assert_equal(response.body.size, response.headers["content-length"].to_i)
    end

    test "it closes original body if rendering console" do
      Thread.current[:__web_console_binding] = binding
      inner_app = Application.new(response_content_type: "text/html")
      @app = Middleware.new(inner_app)

      get "/", params: nil

      assert(inner_app.body.closed?, "body should be closed")
    end

    test "does not render console if response format is empty" do
      Thread.current[:__web_console_binding] = binding
      @app = Middleware.new(Application.new(response_content_type: nil))

      get "/", params: nil

      assert_select "#console", 0
    end

    test "does not render console if response format is not HTML" do
      Thread.current[:__web_console_binding] = binding
      @app = Middleware.new(Application.new(response_content_type: "application/json"))

      get "/", params: nil

      assert_select "#console", 0
    end

    test "returns x-web-console-session-id as response header" do
      Thread.current[:__web_console_binding] = binding

      get "/", params: nil

      session_id = response.headers["x-web-console-session-id"]

      assert_not Session.find(session_id).nil?
    end

    test "doesn't render console in non html response" do
      Thread.current[:__web_console_binding] = binding
      @app = Middleware.new(Application.new(response_content_type: "application/json"))

      get "/", params: nil

      assert_select "#console", 0
    end

    test "doesn't render console from not allowed IP" do
      Thread.current[:__web_console_binding] = binding
      Request.stubs(:permissions).returns(IPAddr.new("127.0.0.1"))

      silence(:stderr) do
        get "/", params: nil, headers: { "REMOTE_ADDR" => "1.1.1.1" }
      end

      assert_select "#console", 0
    end

    test "doesn't render console without a web_console.binding or web_console.exception" do
      get "/", params: nil

      assert_select "#console", 0
    end

    test "can evaluate code and return it as a JSON" do
      session, line = Session.new([[binding]]), __LINE__

      Session.stubs(:from).returns(session)

      get "/", params: nil
      put "/repl_sessions/#{session.id}", xhr: true, params: { input: "line" }

      assert_equal("=> #{line}\n", JSON.parse(response.body)["output"])
    end

    test "can switch bindings on error pages" do
      session = Session.new([WebConsole::ExceptionMapper.new(raise_exception)])

      Session.stubs(:from).returns(session)

      get "/", params: nil
      post "/repl_sessions/#{session.id}/trace", xhr: true, params: { frame_id: 1 }

      assert_equal({ ok: true }.to_json, response.body)
    end

    test "can switch to the cause on error pages" do
      nested_error = begin
                       raise "First error"
                     rescue
                       raise "Second Error" rescue $!
                     end

      session = Session.new(WebConsole::ExceptionMapper.follow(nested_error))

      Session.stubs(:from).returns(session)

      get "/", params: nil
      post "/repl_sessions/#{session.id}/trace", xhr: true, params: { frame_id: 1, exception_object_id: nested_error.cause.object_id }

      assert_equal({ ok: true }.to_json, response.body)
    end

    test "can be changed mount point" do
      Middleware.mount_point = "/customized/path"

      session, value = Session.new([[binding]]), __LINE__
      put "/customized/path/repl_sessions/#{session.id}", params: { input: "value" }, xhr: true

      assert_equal("=> #{value}\n", JSON.parse(response.body)["output"])
    end

    test "can return context information by passing a context param" do
      hello = hello = "world"
      session = Session.new([[binding]])
      Session.stubs(:from).returns(session)

      get "/"
      put "/repl_sessions/#{session.id}", xhr: true, params: { context: "" }

      assert_includes(JSON.parse(response.body)["context"], local_variables.map(&:to_s))
    end

    test "unavailable sessions respond to the user with a message" do
      put "/repl_sessions/no_such_session", xhr: true, params: { input: "__LINE__" }

      assert_equal(404, response.status)
    end

    test "unavailable sessions can occur on binding switch" do
      post "/repl_sessions/no_such_session/trace", xhr: true, params: { frame_id: 1 }

      assert_equal(404, response.status)
    end

    test "reraises application errors" do
      @app = proc { raise }

      assert_raises(RuntimeError) { get "/" }
    end

    test "logs internal errors with Rails.logger" do
      io = StringIO.new
      logger = ActiveSupport::Logger.new(io)
      old_logger, Rails.logger = Rails.logger, logger

      begin
        @app.stubs(:call_app).raises("whoops")

        get "/"
      rescue RuntimeError
        output = io.rewind && io.read
        lines = output.lines

        assert_equal ["\n", "RuntimeError: whoops\n"], lines.slice!(0, 2)
      ensure
        Rails.logger = old_logger
      end
    end

    private

      def raise_exception
        raise
      rescue => exc
        exc
      end
  end
end
