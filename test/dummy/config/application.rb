# frozen_string_literal: true

require File.expand_path("../boot", __FILE__)

require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)
require "web_console"

module Dummy
  class Application < Rails::Application
    # Run outside of the development mode so our test suite runs.
    config.web_console.development_only = false

    config.active_support.test_order = :random
  end
end
