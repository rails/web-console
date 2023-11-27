# frozen_string_literal: true

require "test_helper"

module WebConsole
  class EvaluatorTest < ActiveSupport::TestCase
    class TestError < StandardError
      def backtrace
        [
          "/web-console/lib/web_console/repl.rb:16:in `eval'",
          "/web-console/lib/web_console/repl.rb:16:in `eval'"
        ]
      end
    end

    class BadlyDefinedError < StandardError
      def backtrace
        nil
      end
    end

    setup do
      @repl1 = @repl = Evaluator.new
      @repl2         = Evaluator.new
    end

    test "sending input returns the result as output" do
      assert_equal "=> 42\n", @repl.eval("foo = 42")
    end

    test "preserves the session in the binding" do
      assert_equal "=> 42\n", @repl.eval("foo = 42")
      assert_equal "=> 50\n", @repl.eval("foo + 8")
    end

    test "session preservation requires same bindings" do
      assert_equal "=> 42\n", @repl1.eval("foo = 42")
      assert_equal "=> 42\n", @repl2.eval("foo")
    end

    test "formats exceptions similarly to IRB" do
      repl = Evaluator.new(binding)

      assert_equal <<-END.strip_heredoc, repl.eval("raise TestError, 'panic'")
        #{TestError.name}: panic
        \tfrom /web-console/lib/web_console/repl.rb:16:in `eval'
        \tfrom /web-console/lib/web_console/repl.rb:16:in `eval'
      END
    end

    test "no backtrace is shown if exception backtrace is blank" do
      repl = Evaluator.new(binding)

      assert_equal <<-END.strip_heredoc, repl.eval("raise BadlyDefinedError")
        #{BadlyDefinedError.name}: #{BadlyDefinedError.name}
      END
    end

    test "Evaluator callers are cleaned up of unneeded backtraces", only: :ruby do
      # Those have to be on the same line to get the same trace.
      repl, trace = Evaluator.new(binding), current_trace

      assert_equal <<-END.strip_heredoc, repl.eval("raise 'oops'")
        RuntimeError: oops
        \tfrom #{trace}
      END
    end

    test "Evaluator preserve the last value in the _ variable" do
      @repl.class.last_evaluation_variable = "_"
      assert_equal "=> 42\n", @repl.eval("foo = 42")
      assert_equal "=> 42\n", @repl.eval("_")
      assert_equal "=> 50\n", @repl.eval("_ + 8")
      assert_equal "=> 50\n", @repl.eval("_")
    end

    test "last evaluation variable can be configured" do
      assert_equal "=> 42\n", @repl.eval("foo = 42")
      assert_equal "=> 42\n", @repl.eval("_")
      @repl.class.last_evaluation_variable = "$_last_value"
      assert_equal "=> 42\n", @repl.eval("foo = 42")
      assert_equal "=> 42\n", @repl.eval("$_last_value")
    end

    private

      def current_trace
        caller.first
      end
  end
end
