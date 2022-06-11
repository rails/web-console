# frozen_string_literal: true

require "test_helper"

module WebConsole
  class HelperTest < ActionDispatch::IntegrationTest
    class BaseApplication
      def call(env)
        [ status, headers, body ]
      end

      private

        def request
          Request.new(@env)
        end

        def status
          500
        end

        def headers
          { "content-type" => "text/html; charset=utf-8" }
        end

        def body
          Array(<<-HTML.strip_heredoc)
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
    end

    class SingleConsoleApplication < BaseApplication
      def call(env)
        @env = env

        console

        super
      end
    end

    class MultipleConsolesApplication < BaseApplication
      def call(env)
        @env = env

        console
        console

        super
      end
    end

    setup do
      Thread.current[:__web_console_exception] = nil
      Thread.current[:__web_console_binding] = nil

      Request.stubs(:permissions).returns(IPAddr.new("0.0.0.0/0"))

      @app = Middleware.new(SingleConsoleApplication.new)
    end

    test "renders a console into a view" do
      get "/", params: nil, headers: { "CONTENT_TYPE" => "text/html" }

      assert_select "#console"
    end

    test "raises an error when trying to spawn a console more than once" do
      @app = Middleware.new(MultipleConsolesApplication.new)

      assert_raises(DoubleRenderError) do
        get "/", params: nil, headers: { "CONTENT_TYPE" => "text/html" }
      end
    end

    test "doesn't hijack current view" do
      get "/", params: nil, headers: { "CONTENT_TYPE" => "text/html" }

      assert_select "#hello-world"
      assert_select "#console"
    end
  end
end
