require "web_console/testing/fake_middleware"

TEST_ROOT = Pathname(__FILE__).dirname

# e.g. "/node_modules/mocha/mocha.js"
map "/node_modules" do
  node_modules = TEST_ROOT.join("node_modules")
  unless node_modules.directory?
    abort "ERROR: the node_modules/ directory is not found (You must run `npm install`)"
  end
  run Rack::Directory.new(node_modules)
end

# test runners
map "/html" do
  run WebConsole::Testing::FakeMiddleware.new(
    req_path_regex: %r{^/html/(.*)},
    headers: {"content-type" => "text/html"},
    view_path: TEST_ROOT.join("html"),
  )
end

map "/spec" do
  run WebConsole::Testing::FakeMiddleware.new(
    req_path_regex: %r{^/spec/(.*)},
    view_path: TEST_ROOT.join("spec"),
  )
end

map "/test" do
  run WebConsole::Testing::FakeMiddleware.new(
    req_path_regex: %r{^/test/(.*)},
    view_path: TEST_ROOT.join("test"),
  )
end

map "/templates" do
  run WebConsole::Testing::FakeMiddleware.new(
    req_path_regex: %r{^/templates/(.*)},
    view_path: TEST_ROOT.join("../../lib/web_console/templates"),
  )
end

map "/mock/repl_sessions/result" do
  headers = { 'content-type' => 'application/json' }
  body = [ { output: '=> "fake-result"\n', context: [ [ :something, :somewhat, :somewhere ] ] }.to_json ]
  run lambda { |env| [ 200, headers, body ] }
end

map "/mock/repl_sessions/error" do
  headers = { 'content-type' => 'application/json' }
  body = [ { output: 'fake-error-message' }.to_json ]
  run lambda { |env| [ 400, headers, body ] }
end

map "/mock/repl_sessions/error.txt" do
  headers = { 'content-type' => 'plain/text' }
  body = [ 'error message' ]
  run lambda { |env| [ 400, headers, body ] }
end
