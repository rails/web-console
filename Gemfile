# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

if ENV["RAILS_VERSION"] == "edge"
  gem "rails", github: "rails/rails", branch: "main"
elsif ENV["RAILS_VERSION"]
  gem "activesupport", "~> #{ENV["RAILS_VERSION"]}.0"
else
  gem "rails"
end
gem "rack"

group :development do
  platform :ruby do
    gem "byebug"
  end
  gem "puma"
end

group :test do
  gem "rake"
  gem "mocha", require: false
  gem "simplecov", require: false
end
